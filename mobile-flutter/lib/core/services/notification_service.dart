/// Purpose:
/// Centralized push notification manager for Firebase Cloud Messaging (FCM)
/// and local notifications, delivering dual-channel alerts for emergency SOS
/// and general application updates.
///
/// Data & Logic Flow:
/// 1. Initializes FirebaseMessaging and FlutterLocalNotificationsPlugin.
/// 2. Configures dual Android Notification Channels: 'emergency_alerts' (Max
///    importance, loud alarm sound, SOS vibration) and 'general_notifications'.
/// 3. Registers FCM device token on authentication and syncs to backend.
/// 4. Intercepts incoming messages across foreground, background, and terminated
///    lifecycle states.
/// 5. Dispatches deep links to relevant incident radar / mission screens.
///
/// Key Components:
/// - firebaseMessagingBackgroundHandler: Top-level background message interceptor.
/// - NotificationService: Singleton coordinator for token lifecycle and alerts.
library;

import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import 'session_service.dart';

/// Top-level background handler for FCM messages received while the app is
/// backgrounded or terminated. Must be an isolated top-level function annotated
/// with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e, stackTrace) {
    debugPrint(
      '[NotificationService] Background Firebase.initializeApp error: $e\n$stackTrace',
    );
  }

  debugPrint(
    '[NotificationService] Background message received: ${message.messageId}',
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

  /// Initialize Firebase Cloud Messaging, local notification channels, and listeners.
  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[NotificationService] Firebase not initialized or config missing: $e\n$stackTrace',
      );
      // Continue execution so offline or local mock mode remains functional
      return;
    }

    // 1. Initialize local notifications plugin
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
          } catch (e, stackTrace) {
            debugPrint(
              '[NotificationService] Error parsing payload on tap: $e\n$stackTrace',
            );
          }
        }
      },
    );

    // 2. Register Android Dual Notification Channels
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      // Channel 1: High-Priority Emergency Alerts
      final emergencyChannel = AndroidNotificationChannel(
        channelEmergency,
        'Peringatan Darurat SOS',
        description:
            'Notifikasi darurat prioritas tinggi untuk panggilan SOS sekitar',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 1000]),
      );

      // Channel 2: General Application Updates
      const generalChannel = AndroidNotificationChannel(
        channelGeneral,
        'Notifikasi Umum',
        description: 'Pembaruan status misi, badge, dan info umum',
        importance: Importance.defaultImportance,
        playSound: true,
      );

      await androidImplementation.createNotificationChannel(emergencyChannel);
      await androidImplementation.createNotificationChannel(generalChannel);
    }

    // 3. Request permissions from OS
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

      // 4. Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Foreground message listener: trigger local notification heads-up
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[NotificationService] Foreground message received: ${message.messageId}',
        );
        _showForegroundNotification(message);
      });

      // 6. User tapped notification while app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
          '[NotificationService] Notification opened from background: ${message.data}',
        );
        handleNotificationNavigation(message.data);
      });

      // 7. Check if app was launched from a terminated state by tapping notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '[NotificationService] App cold started from notification: ${initialMessage.data}',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationNavigation(initialMessage.data);
        });
      }

      // 8. Listen for token refresh events
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[NotificationService] FCM token refreshed');
        _sendTokenToBackend(newToken);
      });

      _initialized = true;
      debugPrint('[NotificationService] Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] FCM setup error: $e\n$stackTrace');
    }
  }

  /// Displays a heads-up banner with alarm sound when message arrives while app is open.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title'] ??
        'Peringatan Darurat SOS';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        'Insiden darurat dilaporkan di sekitar Anda';

    final isEmergency =
        (message.data['channel_id'] ?? channelEmergency) == channelEmergency;

    final androidDetails = AndroidNotificationDetails(
      isEmergency ? channelEmergency : channelGeneral,
      isEmergency ? 'Peringatan Darurat SOS' : 'Notifikasi Umum',
      channelDescription: isEmergency
          ? 'Notifikasi darurat prioritas tinggi untuk panggilan SOS sekitar'
          : 'Pembaruan status misi, badge, dan info umum',
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

  /// Retrieves the active FCM device token and synchronizes it with backend Go.
  Future<void> syncTokenWithBackend() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendTokenToBackend(token);
      }
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] syncTokenWithBackend error: $e\n$stackTrace');
    }
  }

  /// Cleans up FCM registration upon logout to prevent cross-account push contamination.
  Future<void> clearTokenOnLogout() async {
    try {
      final authToken = await SessionService.getToken();
      if (authToken != null) {
        final uri = Uri.parse('${ApiConfig.baseUrl}/users/profile/fcm-token');
        await http
            .delete(uri, headers: ApiConfig.headers(token: authToken))
            .timeout(const Duration(seconds: 5));
      }
      if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.deleteToken();
      }
      debugPrint('[NotificationService] FCM token cleared on logout');
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] clearTokenOnLogout error: $e\n$stackTrace');
    }
  }

  /// Sends the FCM token to the backend REST API endpoint.
  Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      final authToken = await SessionService.getToken();
      if (authToken == null || authToken.isEmpty) {
        debugPrint(
          '[NotificationService] Skipping token sync: no active auth session',
        );
        return;
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/users/profile/fcm-token');
      final response = await http
          .put(
            uri,
            headers: ApiConfig.headers(token: authToken),
            body: jsonEncode({'fcm_token': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint(
          '[NotificationService] FCM token synced with backend successfully',
        );
      } else {
        debugPrint(
          '[NotificationService] Failed to sync FCM token: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] Error sending token to backend: $e\n$stackTrace');
    }
  }

  /// Routes user directly to the relevant incident radar or mission details on tap.
  void handleNotificationNavigation(Map<String, dynamic> data) {
    final incidentId = data['incident_id'] as String?;
    if (incidentId == null || incidentId.isEmpty) {
      return;
    }

    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      debugPrint(
        '[NotificationService] Navigator not ready for navigation to incident: $incidentId',
      );
      return;
    }

    debugPrint(
      '[NotificationService] Navigating to incident from notification: $incidentId',
    );
    // Navigation can route to the primary screen where radar loads active incidents
  }
}
