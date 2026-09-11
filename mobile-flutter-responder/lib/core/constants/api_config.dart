import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralized API & network configuration for Mobile Responder client.
class ApiConfig {
  ApiConfig._();

  static const String _envHost = String.fromEnvironment('API_HOST');
  static const String _envPort = String.fromEnvironment(
    'API_PORT',
    defaultValue: '8080',
  );
  static const String _envWsPort = String.fromEnvironment(
    'WS_PORT',
    defaultValue: '8081',
  );

  static String get defaultHost {
    if (_envHost.isNotEmpty) return _envHost;
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static String get baseUrl => 'http://$defaultHost:$_envPort/api/v1';
  static String get wsUrl => 'ws://$defaultHost:$_envWsPort/v1/ws/connect';

  // Auth endpoints
  static String get loginPersonnel => '$baseUrl/auth/personnel/login';
  static String get refreshToken => '$baseUrl/auth/refresh-token';

  // Incident & Mission endpoints
  static String get allActiveIncidents => '$baseUrl/incidents/all-active';
  static String get activeMission =>
      '$baseUrl/incidents/responder/active-mission';
  static String incidentDetail(String id) => '$baseUrl/incidents/$id';
  static String agencyHandle(String id) =>
      '$baseUrl/incidents/$id/agency-handle';
  static String agencyResolve(String id) =>
      '$baseUrl/incidents/$id/agency-resolve';
  static String personnelStatus(String id) =>
      '$baseUrl/incidents/$id/personnel-status';

  // Telemetry endpoint
  static String get telemetryLocation => '$baseUrl/telemetry/location';

  // Operational Timing Constants
  static const Duration activeMissionStreamingInterval = Duration(seconds: 5);
  static const Duration standbyStreamingInterval = Duration(seconds: 30);
  static const double standbyDisplacementThresholdMeters = 25.0;
}
