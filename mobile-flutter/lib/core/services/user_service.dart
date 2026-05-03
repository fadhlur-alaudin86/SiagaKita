import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../models/user_model.dart';

class UserService {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const _timeout = Duration(seconds: 30);

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

  static Future<UserModel> updateProfile(
    String token,
    UserModel updatedUser,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/users/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'phone_number': updatedUser.phoneNumber,
              'birth_date': updatedUser.birthDate,
              'bio': updatedUser.bio,
              'medical_data': updatedUser.medicalData,
              'emergency_contacts': updatedUser.emergencyContacts,
            }),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Gagal memperbarui profil');
      }

      return UserModel.fromJson(body['data']);
    } catch (e) {
      throw Exception('Kesalahan membarui profil: $e');
    }
  }
}
