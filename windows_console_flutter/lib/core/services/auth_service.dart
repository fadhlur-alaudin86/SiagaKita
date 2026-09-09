import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../localization/app_localization.dart';

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String fullName;
  final String role; // 'agency' | 'admin' | 'superadmin'

  const AuthResult({
    required this.accessToken,
    this.refreshToken = '',
    required this.userId,
    required this.fullName,
    required this.role,
  });
}

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'console_access_token';
  static const _refreshTokenKey = 'console_refresh_token';
  static const _roleKey = 'console_role';
  static const _nameKey = 'console_name';

  static bool _isRefreshing = false;
  static final List<Completer<String?>> _refreshQueue = [];

  /// Callback opsional ketika refresh token kedaluwarsa atau invalid
  static VoidCallback? onSessionExpired;

  // ─── Token accessors ────────────────────────────────────────────────────────

  static Future<String?> getAccessToken() => _storage.read(key: _tokenKey);
  static Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  static Future<void> updateTokens(
    String accessToken,
    String refreshToken,
  ) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    if (refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  static Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConstants.login),
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': AppLocalization.currentLocaleCode,
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw AuthException(body['message'] as String? ?? 'Login gagal');
    }

    final data = body['data'] as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String? ?? '';
    final user = data['user'] as Map<String, dynamic>;
    final role = user['role'] as String;

    // Hanya izinkan role yang berhubungan dengan console
    if (role != 'agency' && role != 'admin' && role != 'superadmin') {
      throw AuthException('Email atau password salah.');
    }

    final result = AuthResult(
      accessToken: token,
      refreshToken: refreshToken,
      userId: user['id'] as String,
      fullName: user['full_name'] as String? ?? '',
      role: role,
    );

    // Simpan ke secure storage
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _nameKey, value: result.fullName);

    return result;
  }

  // ─── Restore session ───────────────────────────────────────────────────────

  static Future<AuthResult?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final role = await _storage.read(key: _roleKey);
    final name = await _storage.read(key: _nameKey);
    if (token == null || role == null) return null;
    return AuthResult(
      accessToken: token,
      refreshToken: refreshToken ?? '',
      userId: '',
      fullName: name ?? '',
      role: role,
    );
  }

  // ─── Refresh Token ─────────────────────────────────────────────────────────

  static Future<String?> refreshToken() async {
    if (_isRefreshing) {
      final completer = Completer<String?>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _isRefreshing = true;

    try {
      final currentRefreshToken = await getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        _resolveQueue(null);
        onSessionExpired?.call();
        return null;
      }

      final response = await http.post(
        Uri.parse(ApiConstants.refreshToken),
        headers: {
          'Content-Type': 'application/json',
          'Accept-Language': AppLocalization.currentLocaleCode,
        },
        body: jsonEncode({'refresh_token': currentRefreshToken}),
      );

      if (response.statusCode != 200) {
        await logout();
        _resolveQueue(null);
        onSessionExpired?.call();
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String? ?? '';

      await updateTokens(newAccessToken, newRefreshToken);
      _resolveQueue(newAccessToken);
      return newAccessToken;
    } catch (e) {
      debugPrint('[AuthService] Token refresh error: $e');
      await logout();
      _resolveQueue(null);
      onSessionExpired?.call();
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  static void _resolveQueue(String? token) {
    while (_refreshQueue.isNotEmpty) {
      final completer = _refreshQueue.removeAt(0);
      if (!completer.isCompleted) {
        completer.complete(token);
      }
    }
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ─── Auth header helper ────────────────────────────────────────────────────

  static Map<String, String> headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'Accept-Language': AppLocalization.currentLocaleCode,
  };
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
