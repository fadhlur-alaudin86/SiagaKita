import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_config.dart';
import '../models/user_model.dart';

class UserService {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const _timeout = Duration(seconds: 5);

  // ─── Ambil Profil ────────────────────────────────────────────────────────────

  static Future<UserModel> getProfile(String token) async {
    final prefs = await SharedPreferences.getInstance();
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

      // Cache profile data
      await prefs.setString('cached_profile', jsonEncode(body['data']));

      return UserModel.fromJson(body['data']);
    } catch (e) {
      // Try to load from cache
      final cachedStr = prefs.getString('cached_profile');
      if (cachedStr != null) {
        try {
          return UserModel.fromJson(jsonDecode(cachedStr));
        } catch (_) {}
      }
      throw Exception('Periksa koneksi internet. Kesalahan memuat profil: $e');
    }
  }

  /// Memperbarui UserModel.currentUser dari data terbaru di server.
  static Future<void> refreshCurrentUser(String token) async {
    try {
      final user = await getProfile(token);
      UserModel.currentUser.value = user;
    } catch (e) {
      debugPrint('[UserService] Gagal refresh user: $e');
      // Jangan lempar error agar tidak mengganggu UI jika hanya background refresh
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

      final payload = <String, dynamic>{
        'full_name': updatedUser.name.isNotEmpty ? updatedUser.name : null,
        'nik': updatedUser.nik,
        'phone_number': updatedUser.phoneNumber,
        'place_of_birth': updatedUser.placeOfBirth,
        'date_of_birth': updatedUser.birthDate,
        'blood_type': medData['blood_type'],
        'allergies': medData['allergies'],
        'medical_conditions': medData['medical_history'],
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'domicile': medData['address'],
        'bio': updatedUser.bio,
        'emergency_contacts': contacts ?? [],
      };

      payload.removeWhere((k, v) => v == null);

      final response = await http
          .put(
            Uri.parse('$_baseUrl/users/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
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

  // ─── Save Biodata (POST /users/biodata) ─────────────────────────────────────

  static Future<void> saveBiodata(
    String token,
    UserModel updatedUser,
  ) async {
    try {
      final contacts = updatedUser.emergencyContacts?.map((c) {
        return {
          'name': c['name'] ?? '',
          'phone': c['phone'] ?? '',
          'relation': c['relation'] ?? '',
        };
      }).toList();

      final medData = updatedUser.medicalData ?? {};
      int? heightCm, weightKg;
      if (medData['height'] != null) {
        heightCm = int.tryParse(medData['height'].toString());
      }
      if (medData['weight'] != null) {
        weightKg = int.tryParse(medData['weight'].toString());
      }

      final payload = <String, dynamic>{
        'nik': updatedUser.nik,
        'place_of_birth': updatedUser.placeOfBirth,
        'date_of_birth': updatedUser.birthDate,
        'blood_type': medData['blood_type'],
        'allergies': medData['allergies'],
        'medical_conditions': medData['medical_history'],
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'domicile': medData['address'],
        'emergency_contact_name': contacts != null && contacts.isNotEmpty ? contacts[0]['name'] : null,
        'emergency_contact_phone': contacts != null && contacts.isNotEmpty ? contacts[0]['phone'] : null,
        'emergency_relation': contacts != null && contacts.isNotEmpty ? contacts[0]['relation'] : null,
      };

      payload.removeWhere((k, v) => v == null || v == '');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/users/biodata'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Gagal menyimpan biodata');
      }
    } catch (e) {
      throw Exception('Kesalahan menyimpan biodata: $e');
    }
  }

  // ─── Submit Volunteer Registration ───────────────────────────────────────────
  static Future<void> submitVolunteerRegistration({
    required String accessToken,
    required String experience,
    required List<String> specializations,
    required Map<String, String> certificatesPath, // spec -> file path
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/users/volunteer/register'),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields['experience'] = experience;

      // Kirim semua spesialisasi sebagai satu string (Map<String,String> tidak bisa duplikat key)
      if (specializations.isNotEmpty) {
        request.fields['specializations'] = specializations.join(',');
      }

      // Kirim tipe sertifikat (urutan sama dengan file yang dikirim)
      request.fields['cert_types'] = certificatesPath.keys.toList().join(',');

      // Add certificates — gunakan ekstensi file asli
      for (var entry in certificatesPath.entries) {
        final path = entry.value;
        final specName = entry.key;
        // Ambil ekstensi asli dari path (pdf, jpg, png, dll)
        final ext = path.contains('.')
            ? path.split('.').last.toLowerCase()
            : 'bin';
        final safeSpecName = specName
            .replaceAll('&', 'dan')
            .replaceAll(' ', '_');
        request.files.add(
          await http.MultipartFile.fromPath(
            'certificates',
            path,
            filename: '${safeSpecName}_cert.$ext',
          ),
        );
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          body['message'] ?? 'Gagal mengirim pendaftaran relawan',
        );
      }
    } catch (e) {
      throw Exception('Kesalahan: $e');
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

  // ─── Heartbeat Ping ───────────────────────────────────────────────────────────
  /// Dipanggil setiap 30 detik selama app aktif untuk memperbarui last_active_at.
  /// Jika app di-kill, ping berhenti → admin melihat status Offline.
  static Future<void> ping(String token) async {
    try {
      await http
          .get(
            Uri.parse('$_baseUrl/users/ping'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Abaikan error ping — tidak perlu menampilkan error ke user
    }
  }

  // ─── Update Availability (Khusus Relawan) ───────────────────────────────────
  static Future<void> updateAvailability(String token, bool isAvailable) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/users/volunteer/availability'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'is_available': isAvailable}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Gagal memperbarui status');
      }
    } catch (e) {
      throw Exception('Gagal memperbarui status ketersediaan: $e');
    }
  }
}
