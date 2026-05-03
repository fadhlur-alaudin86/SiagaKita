import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';

class ReportException implements Exception {
  final String message;
  ReportException(this.message);
  @override
  String toString() => message;
}

class ReportModel {
  final String id;
  final String incidentType;
  final String? description;
  final int urgencyLevel;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime createdAt;
  final List<String> photoPaths;
  final String? audioPath;

  const ReportModel({
    required this.id,
    required this.incidentType,
    this.description,
    required this.urgencyLevel,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    this.photoPaths = const [],
    this.audioPath,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] ?? '',
      incidentType: json['incident_type'] ?? '',
      description: json['description'],
      urgencyLevel: json['urgency_level'] ?? 1,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'received',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      photoPaths:
          (json['photo_paths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      audioPath: json['audio_path'],
    );
  }

  String get urgencyLabel {
    switch (urgencyLevel) {
      case 0:
        return 'Ringan';
      case 2:
        return 'Kritis';
      default:
        return 'Sedang';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'processing':
        return 'Diproses';
      case 'resolved':
        return 'Selesai';
      default:
        return 'Diterima';
    }
  }
}

class ReportService {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const _timeout = Duration(seconds: 60);

  // ─── Submit Report with optional media ───────────────────────────────────────
  static Future<void> submitReport({
    required String accessToken,
    required String incidentType,
    required int urgencyLevel,
    required double latitude,
    required double longitude,
    String? description,
    List<File> photos = const [],
    File? audio,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/reports'),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';

      // Text fields
      request.fields['incident_type'] = incidentType;
      request.fields['urgency_level'] = urgencyLevel.toString();
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }

      // Attach photos (max 3)
      for (int i = 0; i < photos.length && i < 3; i++) {
        final photo = photos[i];
        request.files.add(
          await http.MultipartFile.fromPath(
            'photos[]',
            photo.path,
            filename: 'photo_$i.jpg',
          ),
        );
      }

      // Attach audio
      if (audio != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio',
            audio.path,
            filename: 'audio.m4a',
          ),
        );
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ReportException(
          body['message'] as String? ?? 'Gagal mengirim laporan',
        );
      }
    } on ReportException {
      rethrow;
    } catch (e) {
      throw ReportException('Gagal menghubungi server: $e');
    }
  }

  // ─── Get my reports ──────────────────────────────────────────────────────────
  static Future<List<ReportModel>> getMyReports({
    required String accessToken,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/reports/my'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw ReportException(
          body['message'] as String? ?? 'Gagal memuat riwayat laporan',
        );
      }

      final data = body['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ReportException {
      rethrow;
    } catch (e) {
      throw ReportException('Gagal menghubungi server: $e');
    }
  }
}
