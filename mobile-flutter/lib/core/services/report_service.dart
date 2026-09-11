// Purpose: ReportService coordinates citizen non-emergency incident reports and offline queue management.
// Data & Logic Flow: Submits multi-part form reports to backend, buffers failed submissions to LocalStorageService, and provides offline replay when connection restores.
// Key Components: ReportService, ReportModel, ReportException.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../constants/api_config.dart';
import '../localization/app_localization.dart';
import 'local_storage_service.dart';

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
  final int? urgencyLevel; // nullable — ditentukan agensi, bukan warga
  final double latitude;
  final double longitude;
  final String? addressDetail;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<String> photoPaths;
  final String? audioPath;

  const ReportModel({
    required this.id,
    required this.incidentType,
    this.description,
    this.urgencyLevel,
    required this.latitude,
    required this.longitude,
    this.addressDetail,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.photoPaths = const [],
    this.audioPath,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] ?? '',
      incidentType: json['incident_type'] ?? '',
      description: json['description'],
      urgencyLevel: json['urgency_level'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      addressDetail: json['address_detail'],
      status: json['status'] ?? 'sent',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
      photoPaths:
          (json['photo_paths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      audioPath: json['audio_path'],
    );
  }

  String getUrgencyLabel(BuildContext context) {
    if (urgencyLevel == null) return '-';
    switch (urgencyLevel) {
      case 0:
        return 'Ringan'.tr(context);
      case 2:
        return 'Kritis'.tr(context);
      default:
        return 'Sedang'.tr(context);
    }
  }

  String getStatusLabel(BuildContext context) {
    switch (status) {
      case 'handled':
        return 'Ditangani'.tr(context);
      case 'resolved':
        return 'Selesai'.tr(context);
      case 'failed':
        return 'Gagal'.tr(context);
      case 'canceled':
        return 'Dibatalkan'.tr(context);
      case 'rejected':
        return 'Ditolak'.tr(context);
      default:
        return 'Terkirim'.tr(context);
    }
  }
}

class ReportService {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const _timeout = Duration(
    seconds: 60,
  ); // Upload foto butuh waktu lebih panjang (maks 3×2MB)

  // ─── Submit Report with optional media ───────────────────────────────────────
  static Future<void> submitReport({
    required String accessToken,
    required String incidentType,
    required double latitude,
    required double longitude,
    required String addressDetail,
    String? description,
    List<File> photos = const [],
    File? audio,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/reports'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Accept-Language': ApiConfig.headers()['Accept-Language']!,
      });

      // Text fields
      request.fields['incident_type'] = incidentType;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.fields['address_detail'] = addressDetail;
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
      // Save offline if network fails
      await _saveFailedReportLocal(
        incidentType: incidentType,
        latitude: latitude,
        longitude: longitude,
        addressDetail: addressDetail,
        description: description,
        photos: photos,
        audio: audio,
      );
      throw ReportException(
        'Periksa koneksi internet. Laporan disimpan offline.',
      );
    }
  }

  // ─── Offline Queue ───────────────────────────────────────────────────────────
  static Future<void> _saveFailedReportLocal({
    required String incidentType,
    required double latitude,
    required double longitude,
    required String addressDetail,
    String? description,
    List<File> photos = const [],
    File? audio,
  }) async {
    final reportMap = <String, dynamic>{
      'id': 'offline_${const Uuid().v4()}',
      'incident_type': incidentType,
      'latitude': latitude,
      'longitude': longitude,
      'address_detail': addressDetail,
      'description': description,
      'status': 'failed',
      'created_at': DateTime.now().toIso8601String(),
      'photo_paths': photos.map((f) => f.path).toList(),
      'audio_path': audio?.path,
    };

    await LocalStorageService.addFailedReport(reportMap);
  }

  static Future<List<ReportModel>> getFailedReports() async {
    final currentFailed = LocalStorageService.getFailedReports();
    return currentFailed.map((e) => ReportModel.fromJson(e)).toList();
  }

  static Future<void> removeFailedReport(String id) async {
    await LocalStorageService.removeFailedReport(id);
  }

  // ─── Get my reports ──────────────────────────────────────────────────────────
  static Future<List<ReportModel>> getMyReports({
    required String accessToken,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/reports/my'),
            headers: ApiConfig.headers(token: accessToken),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw ReportException(
          body['message'] as String? ?? 'Gagal memuat riwayat laporan',
        );
      }

      final data = body['data'] as List<dynamic>? ?? [];
      final serverReports = data
          .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
          .toList();

      await LocalStorageService.cacheMyReports(data);

      final offlineReports = await getFailedReports();
      return [...offlineReports, ...serverReports];
    } catch (e) {
      final cached = LocalStorageService.getCachedMyReports();
      if (cached != null) {
        try {
          final serverReports = cached
              .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
              .toList();
          final offlineReports = await getFailedReports();
          return [...offlineReports, ...serverReports];
        } catch (_) {}
      }
      throw ReportException(
        'Periksa koneksi internet. Gagal memuat laporan: $e',
      );
    }
  }

  // ─── Resend Failed Report ────────────────────────────────────────────────────
  static Future<void> resendFailedReport({
    required String accessToken,
    required ReportModel failedReport,
  }) async {
    final List<File> photos = failedReport.photoPaths
        .map((p) => File(p))
        .toList();
    final File? audio = failedReport.audioPath != null
        ? File(failedReport.audioPath!)
        : null;

    try {
      await submitReport(
        accessToken: accessToken,
        incidentType: failedReport.incidentType,
        latitude: failedReport.latitude,
        longitude: failedReport.longitude,
        addressDetail: failedReport.addressDetail ?? '',
        description: failedReport.description,
        photos: photos,
        audio: audio,
      );
      // Remove from offline queue if successful
      await removeFailedReport(failedReport.id);
    } catch (e) {
      rethrow; // let UI handle it
    }
  }

  // ─── Cancel Report ───────────────────────────────────────────────────────────
  static Future<void> cancelReport({
    required String accessToken,
    required String reportId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/reports/$reportId/canceled'),
            headers: ApiConfig.headers(token: accessToken),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw ReportException(
          body['message'] as String? ?? 'Gagal membatalkan laporan',
        );
      }
    } on ReportException {
      rethrow;
    } catch (e) {
      throw ReportException('Gagal menghubungi server: $e');
    }
  }
}
