import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../models/user_model.dart';

class UserService {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const _timeout = Duration(seconds: 30);

  // ─── Ambil Profil ────────────────────────────────────────────────────────────

  static Future<UserModel> getProfile(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/users/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Gagal mengambil data profil');
      }

      return UserModel.fromJson(body['data']);
    } catch (e) {
      throw Exception('Kesalahan memuat profil: $e');
    }
  }

  // ─── Update Profil (PUT /users/profile) ──────────────────────────────────────

  static Future<UserModel> updateProfile(
    String token,
    UserModel updatedUser,
  ) async {
    try {
      // Map emergency contacts ke format backend
      final contacts = updatedUser.emergencyContacts?.map((c) {
        return {
          'name': c['name'] ?? '',
          'phone': c['phone'] ?? '',
          'relation': c['relation'] ?? '',
        };
      }).toList();

      // Parse height dan weight menjadi int jika berupa String
      final medData = updatedUser.medicalData ?? {};
      int? heightCm, weightKg;
      if (medData['height'] != null) {
        heightCm = int.tryParse(medData['height'].toString());
      }
      if (medData['weight'] != null) {
        weightKg = int.tryParse(medData['weight'].toString());
      }

      final response = await http
          .put(
            Uri.parse('$_baseUrl/users/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'full_name': updatedUser.name.isNotEmpty ? updatedUser.name : null,
              'date_of_birth': updatedUser.birthDate,
              'blood_type': medData['blood_type'],
              'allergies': medData['allergies'],
              'medical_conditions': medData['medical_history'],
              'height_cm': heightCm,
              'weight_kg': weightKg,
              'alamat': medData['address'],
              'bio': updatedUser.bio,
              'emergency_contacts': contacts ?? [],
            }),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Gagal memperbarui profil');
      }

      return UserModel.fromJson(body['data']);
    } catch (e) {
      throw Exception('Kesalahan memperbarui profil: $e');
    }
  }

  // ─── Verifikasi Nomor HP via WhatsApp OTP ────────────────────────────────────

  /// Kirim OTP WhatsApp ke nomor HP baru.
  static Future<void> requestPhoneOTP(String token, String phoneNumber) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/users/phone/request-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'phone_number': phoneNumber}),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Gagal mengirim OTP');
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  /// Verifikasi kode OTP WhatsApp untuk nomor HP baru.
  static Future<void> verifyPhoneOTP(
    String token,
    String phoneNumber,
    String otpCode,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/users/phone/verify-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'phone_number': phoneNumber,
              'otp_code': otpCode,
            }),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Kode OTP tidak valid');
      }
    } catch (e) {
      throw Exception('$e');
    }
  }
}
