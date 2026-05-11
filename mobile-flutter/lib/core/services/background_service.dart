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

/// Service untuk menjalankan tugas di latar belakang (Foreground Service di Android).
class AppBackgroundService {
  static const notificationChannelId = 'siagakita_bg_channel';
  static const notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId, // id
      'SiagaKita Service', // name
      description: 'Menjaga koneksi ke server SiagaKita', // description
      importance: Importance.low, // low agar tidak bunyi terus
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
        // The entry point for background execution
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'SiagaKita Aktif',
        initialNotificationContent: 'Menjaga koneksi ke server',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      // iOS is not fully supported for this use case yet, but required for config
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
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Hanya berjalan di Isolate terpisah, tidak bisa akses UI/Widget.
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

  // Loop setiap 30 detik
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token');
    if (token == null) {
      // User belum login, skip
      return;
    }

    final baseUrl = ApiConfig.baseUrl;

    // 1. PING: Jaga TTL Redis agar status tetap "Online"
    try {
      await http
          .get(
            Uri.parse('$baseUrl/users/ping'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Abaikan error koneksi
    }

    // 2. LOCATION: Cek apakah fitur "On Duty" aktif
    final isOnDuty = prefs.getBool('is_on_duty') ?? false;
    final role = prefs.getString('session_role');

    if (isOnDuty && role == 'volunteer') {
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

            // Broadcast ke server
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

            // Update notifikasi jika berhasil
            if (service is AndroidServiceInstance) {
              service.setForegroundNotificationInfo(
                title: "Relawan Aktif (On Duty)",
                content: "Berbagi lokasi secara real-time",
              );
            }
          }
        }
      } catch (_) {
        // Abaikan error GPS
      }
    } else {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "SiagaKita Aktif",
          content: "Menjaga koneksi ke server",
        );
      }
    }
  });
}
