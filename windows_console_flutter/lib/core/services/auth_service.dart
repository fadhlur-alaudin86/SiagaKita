import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

class AuthResult {
  final String accessToken;
  final String userId;
  final String fullName;
  final String role; // 'agency' | 'admin' | 'superadmin'

  const AuthResult({
    required this.accessToken,
    required this.userId,
    required this.fullName,
    required this.role,
  });
}

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'console_access_token';
  static const _roleKey = 'console_role';
  static const _nameKey = 'console_name';

  // ─── Login ─────────────────────────────────────────────────────────────────

  static Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConstants.login),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw AuthException(body['message'] as String? ?? 'Login gagal');
    }

    final data = body['data'] as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    final role = user['role'] as String;

    // Hanya izinkan role yang berhubungan dengan console
    if (role != 'agency' && role != 'admin' && role != 'superadmin') {
      throw AuthException('Email atau password salah.');
    }

    final result = AuthResult(
      accessToken: token,
      userId: user['id'] as String,
      fullName: user['full_name'] as String? ?? '',
      role: role,
    );

    // Simpan ke secure storage
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _nameKey, value: result.fullName);

    return result;
  }

  // ─── Restore session ───────────────────────────────────────────────────────

  static Future<AuthResult?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    final role = await _storage.read(key: _roleKey);
    final name = await _storage.read(key: _nameKey);
    if (token == null || role == null) return null;
    return AuthResult(
      accessToken: token,
      userId: '',
      fullName: name ?? '',
      role: role,
    );
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ─── Auth header helper ────────────────────────────────────────────────────

  static Map<String, String> headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
