import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SessionService manages encrypted persistence of JWT tokens, user metadata,
/// active mission states, and responder preferences.
class SessionService {
  SessionService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  static const String _keyAccessToken = 'responder_access_token';
  static const String _keyRefreshToken = 'responder_refresh_token';
  static const String _keyUserId = 'responder_user_id';
  static const String _keyRole = 'responder_role';
  static const String _keyFullName = 'responder_full_name';
  static const String _keyBadgeNumber = 'responder_badge_number';
  static const String _keyActiveIncidentId = 'responder_active_incident_id';
  static const String _keyLocale = 'responder_locale';

  // In-memory token cache to prevent asynchronous delay on hot paths
  static String? _cachedAccessToken;

  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String role,
    String? fullName,
    String? badgeNumber,
  }) async {
    _cachedAccessToken = accessToken;
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyRole, value: role),
      if (fullName != null) _storage.write(key: _keyFullName, value: fullName),
      if (badgeNumber != null) _storage.write(key: _keyBadgeNumber, value: badgeNumber),
    ]);
  }

  static Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
    ]);
  }

  static Future<String?> getToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    _cachedAccessToken = await _storage.read(key: _keyAccessToken);
    return _cachedAccessToken;
  }

  static Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  static Future<String?> getUserId() => _storage.read(key: _keyUserId);
  static Future<String?> getRole() => _storage.read(key: _keyRole);
  static Future<String?> getFullName() => _storage.read(key: _keyFullName);
  static Future<String?> getBadgeNumber() => _storage.read(key: _keyBadgeNumber);

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final role = await getRole();
    return token != null && token.isNotEmpty && role == 'agency_personnel';
  }

  // Active mission state for adaptive background telemetry
  static Future<void> setActiveIncidentId(String? incidentId) async {
    final prefs = await SharedPreferences.getInstance();
    if (incidentId != null && incidentId.isNotEmpty) {
      await prefs.setString(_keyActiveIncidentId, incidentId);
    } else {
      await prefs.remove(_keyActiveIncidentId);
    }
  }

  static Future<String?> getActiveIncidentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActiveIncidentId);
  }

  static Future<bool> hasActiveMission() async {
    final id = await getActiveIncidentId();
    return id != null && id.isNotEmpty;
  }

  // Language preference
  static Future<void> setLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, languageCode);
  }

  static Future<String> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocale) ?? 'id';
  }

  static Future<void> clear() async {
    _cachedAccessToken = null;
    await Future.wait([
      _storage.deleteAll(),
      setActiveIncidentId(null),
    ]);
  }
}
