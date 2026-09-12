/// Purpose:
/// Push notification manager for official agency personnel (mobile-flutter-responder),
/// handling mission dispatch broadcasts and background wake-up alarms via FCM.
///
/// Data & Logic Flow:
/// 1. Initializes FirebaseMessaging and FlutterLocalNotificationsPlugin.
/// 2. Creates 'emergency_alerts' channel with maximum importance and repeating vibration.
/// 3. Synchronizes personnel FCM device token to backend upon session establishment.
/// 4. Intercepts incoming mission assignments and alerts official personnel.
/// 5. Routes deep link directly to MissionBoardScreen or MissionDetailScreen.
///
/// Key Components:
/// - firebaseMessagingBackgroundHandler: Background message interceptor.
/// - NotificationService: Singleton manager for responder push notifications.
library;

import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/api_config.dart';
import 'api_client.dart';
import 'session_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint(
      '[ResponderNotification] Background Firebase.initializeApp error: $e',
    );
  }

  debugPrint(
    '[ResponderNotification] Background dispatch message: ${message.messageId}',
  );
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  static const String channelEmergency = 'emergency_alerts';
  static const String channelGeneral = 'general_notifications';

  /// Initializes FCM and notification channels for the responder client.
  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint(
        '[ResponderNotification] Firebase not configured or offline: $e',
      );
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            handleNotificationNavigation(data);
          } catch (e) {
            debugPrint('[ResponderNotification] Payload parse error: $e');
          }
        }
      },
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      final emergencyChannel = AndroidNotificationChannel(
        channelEmergency,
        'Penugasan Darurat Unit',
        description:
            'Panggilan penugasan misi darurat resmi untuk responder instansi',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 1000]),
      );

      const generalChannel = AndroidNotificationChannel(
        channelGeneral,
        'Notifikasi Umum',
        description: 'Informasi dan pembaruan operasional responder',
        importance: Importance.defaultImportance,
        playSound: true,
      );

      await androidImplementation.createNotificationChannel(emergencyChannel);
      await androidImplementation.createNotificationChannel(generalChannel);
    }

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[ResponderNotification] Foreground dispatch alert: ${message.messageId}',
        );
        _showForegroundNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
          '[ResponderNotification] Opened from background: ${message.data}',
        );
        handleNotificationNavigation(message.data);
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '[ResponderNotification] Cold started from notification: ${initialMessage.data}',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationNavigation(initialMessage.data);
        });
      }

      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[ResponderNotification] Personnel FCM token refreshed');
        _sendTokenToBackend(newToken);
      });

      _initialized = true;
      debugPrint('[ResponderNotification] Initialized successfully');
    } catch (e) {
      debugPrint('[ResponderNotification] FCM setup error: $e');
    }
  }

  /// Displays heads-up notification banner with loud sound when personnel app is open.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title'] ??
        'PENUGASAN MISI BARU';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        'Panggilan penugasan darurat baru telah diterima';

    final isEmergency =
        (message.data['channel_id'] ?? channelEmergency) == channelEmergency;

    final androidDetails = AndroidNotificationDetails(
      isEmergency ? channelEmergency : channelGeneral,
      isEmergency ? 'Penugasan Darurat Unit' : 'Notifikasi Umum',
      channelDescription: isEmergency
          ? 'Panggilan penugasan misi darurat resmi untuk responder instansi'
          : 'Informasi dan pembaruan operasional responder',
      importance: isEmergency ? Importance.max : Importance.defaultImportance,
      priority: isEmergency ? Priority.high : Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
      vibrationPattern: isEmergency
          ? Int64List.fromList([0, 500, 200, 500, 200, 1000])
          : null,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final payloadStr = jsonEncode(message.data);
    final notificationId = message.hashCode;

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payloadStr,
    );
  }

  /// Retrieves active personnel FCM token and synchronizes it with backend Go.
  Future<void> syncTokenWithBackend() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[ResponderNotification] syncTokenWithBackend error: $e');
    }
  }

  /// Cleans up FCM token upon responder logout.
  Future<void> clearTokenOnLogout() async {
    try {
      final token = await SessionService.getToken();
      if (token != null) {
        await ApiClient.delete('${ApiConfig.baseUrl}/users/profile/fcm-token');
      }
      if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.deleteToken();
      }
      debugPrint('[ResponderNotification] FCM token cleared on logout');
    } catch (e) {
      debugPrint('[ResponderNotification] clearTokenOnLogout error: $e');
    }
  }

  /// Sends FCM token to backend profile endpoint.
  Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      final token = await SessionService.getToken();
      if (token == null || token.isEmpty) return;

      final res = await ApiClient.put(
        '${ApiConfig.baseUrl}/users/profile/fcm-token',
        body: {'fcm_token': fcmToken},
      );

      if (res.statusCode == 200) {
        debugPrint('[ResponderNotification] Personnel FCM token registered');
      } else {
        debugPrint(
          '[ResponderNotification] Failed to sync token: ${res.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[ResponderNotification] Error sending token: $e');
    }
  }

  /// Routes responder directly to mission detail screen upon notification tap.
  void handleNotificationNavigation(Map<String, dynamic> data) {
    final incidentId = data['incident_id'] as String?;
    if (incidentId == null || incidentId.isEmpty) return;

    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      debugPrint(
        '[ResponderNotification] Navigator state not ready: $incidentId',
      );
      return;
    }

    debugPrint(
      '[ResponderNotification] Navigating to assigned mission: $incidentId',
    );
  }
}
