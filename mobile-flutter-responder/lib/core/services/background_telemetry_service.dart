import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import 'session_service.dart';

/// BackgroundTelemetryService runs continuous GPS telemetry streaming to
/// PUT /api/v1/telemetry/location using an adaptive frequency policy:
/// - High frequency (5-10s) during active missions (en_route / on_scene)
/// - Relaxed frequency (30-60s) during standby to conserve battery.
class BackgroundTelemetryService {
  BackgroundTelemetryService._();

  static const String notificationChannelId = 'responder_telemetry_channel';
  static const int notificationId = 999;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'SiagaKita Responder Fleet Telemetry',
      description:
          'Menjaga pelacakan koordinat armada lapangan ke Markas Komando',
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
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'SiagaKita Responder Aktif',
        initialNotificationContent: 'Menghubungkan ke Markas Komando...',
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
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    double? lastLat;
    double? lastLng;
    DateTime lastStreamTime = DateTime.fromMillisecondsSinceEpoch(0);

    Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final token = await SessionService.getToken();
        if (token == null || token.isEmpty) return;

        final hasActiveMission = await SessionService.hasActiveMission();

        final now = DateTime.now();
        final elapsed = now.difference(lastStreamTime);

        // Check if permission is granted
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: hasActiveMission
                ? LocationAccuracy.high
                : LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          ),
        );

        // Adaptive Decimation Policy
        bool shouldStream = false;
        if (hasActiveMission) {
          // Always stream every 5s during active mission
          shouldStream = true;
        } else {
          // Standby: stream if >= 30s elapsed or displacement > 25m
          if (elapsed >= ApiConfig.standbyStreamingInterval) {
            shouldStream = true;
          } else if (lastLat != null && lastLng != null) {
            final distance = Geolocator.distanceBetween(
              lastLat!,
              lastLng!,
              position.latitude,
              position.longitude,
            );
            if (distance >= ApiConfig.standbyDisplacementThresholdMeters) {
              shouldStream = true;
            }
          }
        }

        if (shouldStream) {
          lastLat = position.latitude;
          lastLng = position.longitude;
          lastStreamTime = now;

          // Stream to backend hot path PUT /api/v1/telemetry/location
          final url = Uri.parse(ApiConfig.telemetryLocation);
          await http
              .put(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                }),
              )
              .timeout(const Duration(seconds: 3));

          // Update foreground notification
          final title = hasActiveMission
              ? 'SiagaKita: Merespons Misi Darurat'
              : 'SiagaKita: Standby Lapangan';
          final content =
              'GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';

          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: title,
              content: content,
            );
          }
        }
      } catch (e) {
        debugPrint(
          '[BackgroundTelemetryService] Error streaming telemetry: $e',
        );
      }
    });
  }
}
