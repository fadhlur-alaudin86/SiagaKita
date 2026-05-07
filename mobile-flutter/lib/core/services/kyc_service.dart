import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';

/// KycService menangani API calls untuk verifikasi identitas NIK warga.
class KycService {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const _timeout = Duration(seconds: 30);

  // ─── GET /users/kyc/status ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStatus({
    required String accessToken,
  }) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/users/kyc/status'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(_timeout);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      return (body['data'] as Map<String, dynamic>?) ?? body;
    }
    throw Exception(body['error'] ?? 'Gagal memuat status KYC');
  }

  // ─── POST /users/kyc ──────────────────────────────────────────────────────

  /// Mengirim pengajuan KYC: NIK, nama, foto KTP, dan foto profil/selfie.
  static Future<void> submitKYC({
    required String accessToken,
    required String nik,
    required String fullName,
    required File ktpPhoto,
    required File selfiePhoto,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/kyc');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['nik'] = nik
      ..fields['full_name'] = fullName
      ..files.add(
        await http.MultipartFile.fromPath('ktp', ktpPhoto.path),
      )
      ..files.add(
        await http.MultipartFile.fromPath('selfie', selfiePhoto.path),
      );

    final streamed = await req.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(body['error'] ?? 'Gagal mengajukan verifikasi NIK');
    }
  }
}
