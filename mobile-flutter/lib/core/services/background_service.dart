import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../constants/api_config.dart';
import 'session_service.dart';

/// Service untuk menjalankan tugas di latar belakang (Foreground Service di Android).
class AppBackgroundService {
  static const notificationChannelId = 'siagakita_bg_channel';
  static const notificationId = 888;

  // SharedPreferences keys untuk komunikasi foreground ↔ background
  static const _keySOSIncidentId = 'bg_sos_incident_id';
  static const _keySOSActive = 'bg_sos_active';

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'SiagaKita Service',
      description: 'Menjaga koneksi ke server SiagaKita',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'SiagaKita Aktif',
        initialNotificationContent: 'Menjaga koneksi ke server',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
  }

  /// Beritahu background service bahwa SOS sedang aktif.
  /// GPS background akan mulai mengirim lokasi ke endpoint incidents/{id}/location.
  static Future<void> startSOSTracking(String incidentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySOSIncidentId, incidentId);
    await prefs.setBool(_keySOSActive, true);
    // Kirim event ke service instance yang sedang berjalan
    FlutterBackgroundService().invoke('startSOSTracking', {
      'incident_id': incidentId,
    });
  }

  /// Beritahu background service bahwa SOS sudah selesai.
  static Future<void> stopSOSTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySOSIncidentId);
    await prefs.setBool(_keySOSActive, false);
    FlutterBackgroundService().invoke('stopSOSTracking');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // ─── Vibration Control ────────────────────────────────────────────────────
  Timer? vibrationTimer;

  service.on('startVibration').listen((event) {
    vibrationTimer?.cancel();
    vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 150, 100, 150]);
      }
    });
  });

  service.on('stopVibration').listen((event) {
    vibrationTimer?.cancel();
    vibrationTimer = null;
    Vibration.cancel();
  });

  // ─── SOS GPS Tracking (Background) ────────────────────────────────────────
  // Saat app diminimalkan, kirim lokasi setiap 5 detik selama SOS aktif.
  String? sosIncidentId;
  Timer? sosLocationTimer;

  void stopSOSTimer() {
    sosLocationTimer?.cancel();
    sosLocationTimer = null;
    sosIncidentId = null;
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'SiagaKita Aktif',
        content: 'Menjaga koneksi ke server',
      );
    }
  }

  void startSOSTimer(String incidentId) {
    sosIncidentId = incidentId;
    sosLocationTimer?.cancel();

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: '🆘 SOS Aktif — Berbagi Lokasi',
        content: 'Lokasi Anda sedang dikirim ke tim respons',
      );
    }

    sosLocationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (sosIncidentId == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = await SessionService.getToken();
      final sosActive = prefs.getBool('bg_sos_active') ?? false;

      if (token == null || !sosActive) {
        stopSOSTimer();
        return;
      }

      try {
        final hasPermission = await Geolocator.checkPermission();
        if (hasPermission == LocationPermission.always ||
            hasPermission == LocationPermission.whileInUse) {
          final isGpsOn = await Geolocator.isLocationServiceEnabled();
          if (!isGpsOn) return;

          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          );

          await http
              .put(
                Uri.parse(
                  '${ApiConfig.baseUrl}/incidents/$sosIncidentId/location',
                ),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                }),
              )
              .timeout(const Duration(seconds: 8));
        }
      } catch (_) {
        // Silent fail — akan dicoba di interval berikutnya
      }
    });
  }

  service.on('startSOSTracking').listen((event) {
    final incidentId = event?['incident_id'] as String?;
    if (incidentId != null && incidentId.isNotEmpty) {
      startSOSTimer(incidentId);
    }
  });

  service.on('stopSOSTracking').listen((event) {
    stopSOSTimer();
  });

  // ─── Regular Background Loop (setiap 30 detik) ───────────────────────────
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token');
    if (token == null) return;

    final baseUrl = ApiConfig.baseUrl;

    // 1. PING: Jaga TTL Redis agar status tetap "Online"
    try {
      await http
          .get(
            Uri.parse('$baseUrl/users/ping'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}

    // 2. LOCATION: Cek apakah fitur "On Duty" aktif (Relawan)
    // Hanya kirim lokasi relawan jika bukan sedang dalam mode SOS
    final isOnDuty = prefs.getBool('is_on_duty') ?? false;
    final role = prefs.getString('session_role');
    final isSosActive = prefs.getBool('bg_sos_active') ?? false;

    if (isOnDuty && role == 'volunteer' && !isSosActive) {
      try {
        final hasPermission = await Geolocator.checkPermission();
        if (hasPermission == LocationPermission.always ||
            hasPermission == LocationPermission.whileInUse) {
          final isGpsOn = await Geolocator.isLocationServiceEnabled();
          if (isGpsOn) {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              ),
            );

            await http
                .put(
                  Uri.parse('$baseUrl/telemetry/location'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'latitude': position.latitude,
                    'longitude': position.longitude,
                  }),
                )
                .timeout(const Duration(seconds: 10));

            if (service is AndroidServiceInstance) {
              service.setForegroundNotificationInfo(
                title: "Relawan Aktif (On Duty)",
                content: "Berbagi lokasi secara real-time",
              );
            }
          }
        }
      } catch (_) {}
    } else if (!isSosActive) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "SiagaKita Aktif",
          content: "Menjaga koneksi ke server",
        );
      }
    }
  });
}
