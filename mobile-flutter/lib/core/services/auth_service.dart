import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';

/// AuthService menangani komunikasi auth dengan backend Go.
class AuthService {
  static const String _baseUrl = ApiConfig.baseUrl;

  // Timeout default untuk semua request auth
  static const _timeout = Duration(seconds: 30);

  // ─── Helper: safe HTTP call dengan timeout ────────────────────────────────

  static Future<http.Response> _post(String url, Map<String, dynamic> body,
      {Map<String, String>? headers}) async {
    try {
      return await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
            body: jsonEncode(body),
          )
          .timeout(
            _timeout,
            onTimeout: () => throw AuthException(
              'Server terlalu lama merespons. Coba lagi.',
            ),
          );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException('Gagal menghubungi server. Periksa koneksi internet.');
    }
  }

  // ─── Register Step 1: buat akun → kirim OTP ke email ─────────────────────
  static Future<String> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _post('$_baseUrl/auth/register', {
      'full_name': fullName,
      'email': email,
      'password': password,
    });
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw AuthException(body['message'] as String? ?? 'Pendaftaran gagal');
    }
    // Kembalikan email untuk dipakai di step OTP
    return (body['data'] as Map<String, dynamic>?)?['email'] as String? ?? email;
  }

  // ─── Register Step 2: verifikasi OTP email → return token ────────────────
  static Future<AuthResult> verifyRegisterOTP({
    required String email,
    required String otpCode,
  }) async {
    final response = await _post(
      '$_baseUrl/auth/verify-register-otp',
      {'email': email, 'otp_code': otpCode},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException(body['message'] as String? ?? 'Verifikasi OTP gagal');
    }
    return AuthResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ─── Login: email+password → JWT langsung ────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '$_baseUrl/auth/login',
      {'email': email, 'password': password},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException(body['message'] as String? ?? 'Login gagal');
    }
    return AuthResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ─── Login OTP: verifikasi OTP email → return token ──────────────────────
  static Future<AuthResult> verifyLoginOTP({
    required String email,
    required String otpCode,
  }) async {
    final response = await _post(
      '$_baseUrl/auth/verify-login-otp',
      {'email': email, 'otp_code': otpCode},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException(body['message'] as String? ?? 'Verifikasi OTP gagal');
    }
    return AuthResult.fromJson(body['data'] as Map<String, dynamic>);
  // ─── Forgot Password ───────────────────────────────────────────────────────
  static Future<void> forgotPassword(String email) async {
    final response = await _post('$_baseUrl/auth/forgot-password', {'email': email});
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw AuthException(body['message'] as String? ?? 'Gagal memproses permintaan');
    }
  }

  // ─── Reset Password ────────────────────────────────────────────────────────
  static Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await _post('$_baseUrl/auth/reset-password', {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw AuthException(body['message'] as String? ?? 'Gagal mereset password');
    }
  }

  // ─── Resend OTP ────────────────────────────────────────────────────────────
  static Future<void> resendOTP({
    required String email,
    required String context,
  }) async {
    final response = await _post('$_baseUrl/auth/resend-otp', {
      'email': email,
      'context': context,
    });
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw AuthException(body['message'] as String? ?? 'Gagal mengirim ulang OTP');
    }
  }
}

// ─── Data classes ──────────────────────────────────────────────────────────────

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final UserInfo user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class UserInfo {
  final String id;
  final String? fullName; // nullable — diambil dari user_profiles
  final String email;
  final String role;

  const UserInfo({
    required this.id,
    this.fullName,
    required this.email,
    required this.role,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        email: json['email'] as String,
        role: json['role'] as String,
      );
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
