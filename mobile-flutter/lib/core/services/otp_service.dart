import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';

/// OTPService menangani komunikasi dengan backend untuk permintaan dan
/// verifikasi kode OTP yang dikirim via WhatsApp.
class OTPService {
  static const String _baseUrl = ApiConfig.baseUrl;

  /// Meminta kode OTP dikirimkan ke [phoneNumber] via WhatsApp.
  ///
  /// Melempar [OTPException] jika:
  /// - Rate limit aktif (cooldown 1 menit)
  /// - Pengiriman WA gagal
  /// - Server error
  static Future<void> requestOTP(String phoneNumber) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phoneNumber}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final message = body['message'] as String? ?? 'Permintaan OTP gagal';
      throw OTPException(
        message: message,
        isRateLimit: response.statusCode == 429,
      );
    }
  }

  /// Memverifikasi [otpCode] untuk [phoneNumber].
  ///
  /// Melempar [OTPException] jika kode salah atau kedaluwarsa.
  static Future<void> verifyOTP(String phoneNumber, String otpCode) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phoneNumber, 'otp_code': otpCode}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final message = body['message'] as String? ?? 'Kode OTP tidak valid';
      throw OTPException(message: message);
    }
  }
}

/// Exception yang dilempar oleh [OTPService].
class OTPException implements Exception {
  final String message;
  final bool isRateLimit;

  const OTPException({required this.message, this.isRateLimit = false});

  @override
  String toString() => message;
}
