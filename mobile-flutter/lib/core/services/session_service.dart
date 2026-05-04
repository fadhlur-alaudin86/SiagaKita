import 'package:shared_preferences/shared_preferences.dart';

/// SessionService menyimpan dan membaca sesi login secara lokal.
/// Memungkinkan auto-login saat app dibuka kembali, bahkan dalam kondisi offline.
class SessionService {
  static const _keyToken = 'session_token';
  static const _keyUserId = 'session_user_id';
  static const _keyEmail = 'session_email';
  static const _keyRole = 'session_role';
  static const _keyName = 'session_name';

  /// Simpan sesi setelah login berhasil.
  static Future<void> saveSession({
    required String token,
    required String userId,
    required String email,
    required String role,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
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
    final token = prefs.getString(_keyToken);
    final userId = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyEmail);
    final role = prefs.getString(_keyRole);
    if (token == null || userId == null || email == null || role == null) {
      return null;
    }
    return SessionData(
      token: token,
      userId: userId,
      email: email,
      role: role,
      name: prefs.getString(_keyName),
    );
  }

  /// Hapus sesi saat logout.
  static Future<void> clearSession() async {
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
  final String userId;
  final String email;
  final String role;
  final String? name;

  const SessionData({
    required this.token,
    required this.userId,
    required this.email,
    required this.role,
    this.name,
  });
}
