import 'dart:convert';
import 'package:http/http.dart' as http;

/// AuthService menangani komunikasi auth dengan backend Go.
class AuthService {
  static const String _baseUrl = 'http://10.0.2.2:8080/api/v1';

  // ─── Register Step 1: buat akun → kirim OTP ke email ─────────────────────
  static Future<String> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
      }),
    );
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
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verify-register-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp_code': otpCode}),
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
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException(body['message'] as String? ?? 'Login gagal');
    }
    return AuthResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ─── Login Step 2: verifikasi OTP email → return token ───────────────────
  static Future<AuthResult> verifyLoginOTP({
    required String email,
    required String otpCode,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verify-login-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp_code': otpCode}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException(body['message'] as String? ?? 'Verifikasi OTP gagal');
    }
    return AuthResult.fromJson(body['data'] as Map<String, dynamic>);
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
  final String? fullName;   // nullable — diambil dari user_profiles
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
