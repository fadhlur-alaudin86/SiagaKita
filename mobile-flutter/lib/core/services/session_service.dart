import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SessionService menyimpan dan membaca sesi login secara lokal.
/// Menggunakan FlutterSecureStorage (hardware-backed Keystore/Keychain)
/// untuk token otentikasi sensitif, dan SharedPreferences untuk preferensi non-sensitif.
class SessionService {
  static const _keyToken = 'session_token';
  static const _keyRefreshToken = 'session_refresh_token';
  static const _keyUserId = 'session_user_id';
  static const _keyEmail = 'session_email';
  static const _keyRole = 'session_role';
  static const _keyName = 'session_name';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  /// Helper untuk mengambil token otentikasi dari secure storage.
  static Future<String?> getToken() async {
    try {
      final token = await _secureStorage.read(key: _keyToken);
      if (token != null) return token;

      // Fallback & migrasi dari legacy SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final legacyToken = prefs.getString(_keyToken);
      if (legacyToken != null) {
        await _secureStorage.write(key: _keyToken, value: legacyToken);
        await prefs.remove(_keyToken);
        return legacyToken;
      }
      return null;
    } catch (_) {
      // Fallback ke SharedPreferences jika hardware keystore mengalami error platform
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyToken);
    }
  }

  /// Helper untuk mengambil refresh token dari secure storage.
  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  /// Update token akses dan refresh token setelah auto-rotation.
  static Future<void> updateTokens(
    String accessToken,
    String refreshToken,
  ) async {
    await _secureStorage.write(key: _keyToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  /// Simpan sesi setelah login berhasil.
  static Future<void> saveSession({
    required String token,
    String? refreshToken,
    required String userId,
    required String email,
    required String role,
    String? name,
  }) async {
    // 1. Simpan token & refresh token di Secure Storage
    await _secureStorage.write(key: _keyToken, value: token);
    if (refreshToken != null) {
      await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
    }

    // 2. Simpan metadata non-sensitif di SharedPreferences untuk performa
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken); // Bersihkan legacy token jika ada
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyRole, role);
    if (name != null) {
      await prefs.setString(_keyName, name);
    }
  }

  /// Baca sesi tersimpan. Kembalikan null jika tidak ada.
  static Future<SessionData?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getToken();
    final refreshToken = await getRefreshToken();
    final userId = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyEmail);
    final role = prefs.getString(_keyRole);
    if (token == null || userId == null || email == null || role == null) {
      return null;
    }
    return SessionData(
      token: token,
      refreshToken: refreshToken,
      userId: userId,
      email: email,
      role: role,
      name: prefs.getString(_keyName),
    );
  }

  /// Hapus sesi saat logout.
  static Future<void> clearSession() async {
    await _secureStorage.delete(key: _keyToken);
    await _secureStorage.delete(key: _keyRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyName);
  }

  /// Update nama pengguna di sesi (setelah edit profil berhasil).
  static Future<void> updateName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
  }
}

class SessionData {
  final String token;
  final String? refreshToken;
  final String userId;
  final String email;
  final String role;
  final String? name;

  const SessionData({
    required this.token,
    this.refreshToken,
    required this.userId,
    required this.email,
    required this.role,
    this.name,
  });
}
