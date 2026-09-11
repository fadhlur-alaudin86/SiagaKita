// Purpose: IncidentService handles REST API calls and offline caching for SOS emergencies and citizen reports.
// Data & Logic Flow: Dispatches HTTP requests to backend endpoints, caches response feeds to LocalStorageService, and provides fallback data during network degradation.
// Key Components: IncidentService.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import 'local_storage_service.dart';

/// IncidentService menangani API calls untuk SOS incidents (Jalur A)
/// dan laporan warga non-darurat (Jalur B).
class IncidentService {
  static const String _baseUrl = ApiConfig.baseUrl;

  // Timeout: SOS-critical calls pakai 5 detik, regular calls 5 detik
  static const _sosTimeout = Duration(seconds: 5);
  static const _defaultTimeout = Duration(seconds: 5);

  // ─── Helper: request dengan timeout ──────────────────────────────────────

  static Future<http.Response> _req(
    Future<http.Response> Function() call, {
    Duration? timeout,
  }) async {
    try {
      return await call().timeout(
        timeout ?? _defaultTimeout,
        onTimeout: () => throw IncidentException(
          'Gagal menghubungi server. Periksa koneksi internet.',
        ),
      );
    } on IncidentException {
      rethrow;
    } on SOSBannedException {
      rethrow;
    } catch (e, stack) {
      debugPrint('[IncidentService] Request failed: $e\n$stack');
      throw IncidentException(
        'Gagal menghubungi server. Periksa koneksi internet: $e',
      );
    }
  }

  static Map<String, String> _authHeader(String token) =>
      ApiConfig.headers(token: token);

  // ─── Trigger SOS (Jalur A) ────────────────────────────────────────────────

  /// Mengirim SOS. Selalu mulai dengan tipe 'unknown'.
  /// Status awal: grace_period. Tipe diupdate via [updateType].
  static Future<TriggerSOSResult> triggerSOS({
    required String accessToken,
    required double latitude,
    required double longitude,
    String? addressDetail,
  }) async {
    final response = await _req(
      () => http.post(
        Uri.parse('$_baseUrl/incidents/trigger'),
        headers: _authHeader(accessToken),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'address_detail': addressDetail,
        }),
      ),
      timeout: _sosTimeout, // SOS harus cepat
    );
    final body = await Isolate.run(
      () => jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (response.statusCode == 403) {
      throw SOSBannedException(
        body['message'] as String? ?? 'Fitur SOS dinonaktifkan',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw IncidentException(
        body['message'] as String? ?? 'Gagal mengirim SOS',
      );
    }
    return TriggerSOSResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ─── Update Type (Grace Period) ───────────────────────────────────────────

  /// Memilih tipe insiden selama grace period.
  static Future<void> updateType({
    required String accessToken,
    required String incidentId,
    required String incidentType,
  }) async {
    final response = await _req(
      () => http.patch(
        Uri.parse('$_baseUrl/incidents/$incidentId/type'),
        headers: _authHeader(accessToken),
        body: jsonEncode({'incident_type': incidentType}),
      ),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw IncidentException(
        body['message'] as String? ?? 'Gagal update tipe',
      );
    }
  }

  // ─── Broadcast (Grace Period Timeout) ────────────────────────────────────

  /// Dipanggil saat countdown habis tanpa memilih tipe.
  static Future<void> broadcast({
    required String accessToken,
    required String incidentId,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/incidents/$incidentId/broadcast'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_defaultTimeout);
    } catch (_) {
      // Silent fail - SOS tetap aktif, status update di iterasi berikutnya
    }
  }

  // ─── Cancel SOS ───────────────────────────────────────────────────────────

  static Future<void> cancelSOS({
    required String accessToken,
    required String incidentId,
  }) async {
    final response = await _req(
      () => http.post(
        Uri.parse('$_baseUrl/incidents/$incidentId/canceled'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      timeout: _sosTimeout,
    );
    if (response.statusCode == 409) {
      throw const SOSConflictException('SOS sudah diselesaikan oleh instansi.');
    }
    if (response.statusCode != 200) {
      String errorMessage = 'Gagal membatalkan SOS';
      try {
        final body = await Isolate.run(
          () => jsonDecode(response.body) as Map<String, dynamic>,
        );
        errorMessage = body['message'] as String? ?? errorMessage;
      } catch (_) {
        // Jika bukan JSON (misal 404 Fiber HTML), ambil text body jika pendek
        if (response.body.length < 100) {
          errorMessage = response.body;
        }
      }
      throw IncidentException(errorMessage);
    }
  }

  // ─── Update Location ──────────────────────────────────────────────────────

  static Future<void> updateLocation({
    required String accessToken,
    required String incidentId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await http
          .put(
            Uri.parse('$_baseUrl/incidents/$incidentId/location'),
            headers: _authHeader(accessToken),
            body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
          )
          .timeout(_defaultTimeout);
    } catch (_) {
      // Silent fail - lokasi diupdate di timer interval berikutnya
    }
  }

  // ─── Upload Evidence (foto + audio pasca broadcasting) ───────────────────

  /// Mengirimkan foto kamera depan, kamera belakang, dan rekaman audio 5 detik
  /// sebagai bukti SOS. Dipanggil secara background segera setelah insiden masuk
  /// fase 'broadcasting'. Tidak melempar exception - error diabaikan (best-effort).
  static Future<void> uploadEvidence({
    required String accessToken,
    required String incidentId,
    File? photoFile,
    File? rearPhotoFile,
    File? audioFile,
  }) async {
    if (photoFile == null && rearPhotoFile == null && audioFile == null) return;
    try {
      final uri = Uri.parse('$_baseUrl/incidents/$incidentId/evidence');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $accessToken';

      if (photoFile != null && photoFile.existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photoFile.path),
        );
      }
      if (rearPhotoFile != null && rearPhotoFile.existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', rearPhotoFile.path),
        );
      }
      if (audioFile != null && audioFile.existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('audio', audioFile.path),
        );
      }

      await request.send().timeout(const Duration(seconds: 30));
    } catch (_) {
      // Best-effort - jika gagal, abaikan (tidak mempengaruhi SOS aktif)
    }
  }

  // ─── Get Active Incident ──────────────────────────────────────────────────

  static Future<ActiveIncident?> getActive({
    required String accessToken,
  }) async {
    final response = await _req(
      () => http.get(
        Uri.parse('$_baseUrl/incidents/active'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    if (response.statusCode != 200) return null;
    final body = await Isolate.run(
      () => jsonDecode(response.body) as Map<String, dynamic>,
    );
    final data = body['data'];
    if (data == null) return null;
    return ActiveIncident.fromJson(data as Map<String, dynamic>);
  }

  // ─── Get My History ───────────────────────────────────────────────────────

  static Future<List<MissionHistory>> getMyHistory({
    required String accessToken,
  }) async {
    try {
      final response = await _req(
        () => http.get(
          Uri.parse('$_baseUrl/incidents/my-history'),
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      if (response.statusCode != 200) {
        final body = await Isolate.run(
          () => jsonDecode(response.body) as Map<String, dynamic>,
        );
        throw IncidentException(
          body['message'] as String? ?? 'Gagal memuat riwayat SOS',
        );
      }
      final body = await Isolate.run(
        () => jsonDecode(response.body) as Map<String, dynamic>,
      );
      final data = body['data'] as List?;
      if (data == null) return [];

      await LocalStorageService.cacheIncidents('cached_my_history', data);

      return data
          .map((e) => MissionHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached =
          LocalStorageService.getCachedIncidents('cached_my_history');
      if (cached != null) {
        try {
          return cached
              .map(
                (e) => MissionHistory.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        } catch (_) {}
      }
      throw IncidentException(
        'Periksa koneksi internet. Gagal memuat riwayat: $e',
      );
    }
  }

  // ─── Get Reporter History ─────────────────────────────────────────────────

  static Future<List<ActiveIncident>> getReporterHistory({
    required String accessToken,
  }) async {
    try {
      final response = await _req(
        () => http.get(
          Uri.parse('$_baseUrl/incidents/reporter-history'),
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw IncidentException(
          body['message'] as String? ?? 'Gagal memuat riwayat SOS',
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List?;
      if (data == null) return [];

      await LocalStorageService.cacheIncidents('cached_reporter_history', data);

      return data
          .map((e) => ActiveIncident.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached =
          LocalStorageService.getCachedIncidents('cached_reporter_history');
      if (cached != null) {
        try {
          return cached
              .map(
                (e) => ActiveIncident.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        } catch (_) {}
      }
      throw IncidentException(
        'Periksa koneksi internet. Gagal memuat riwayat: $e',
      );
    }
  }

  // ─── Get Nearby SOS (untuk Relawan) ──────────────────────────────────────

  /// Mengembalikan SOS aktif dalam radius `radius` km dari posisi relawan.
  /// Dipanggil tiap 30 detik saat ON DUTY.
  static Future<List<NearbyIncident>> getNearby({
    required String accessToken,
    required double lat,
    required double lng,
    double radius = 5.0,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/incidents/nearby?lat=$lat&lng=$lng&radius=$radius',
            ),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_defaultTimeout);
      if (response.statusCode != 200) {
        final cached =
            LocalStorageService.getCachedIncidents('cached_nearby_sos');
        if (cached != null) {
          return cached
              .map(
                (e) => NearbyIncident.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
        return [];
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List?;
      if (data == null) return [];

      await LocalStorageService.cacheIncidents('cached_nearby_sos', data);

      return data
          .map((e) => NearbyIncident.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final cached =
          LocalStorageService.getCachedIncidents('cached_nearby_sos');
      if (cached != null) {
        return cached
            .map(
              (e) => NearbyIncident.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }
      return [];
    }
  }

  // ─── Accept SOS (Relawan menerima misi) ──────────────────────────────────

  /// Relawan menekan tombol "Terima" pada SOS yang tampil di radar.
  static Future<void> acceptSOS({
    required String accessToken,
    required String incidentId,
  }) async {
    final response = await _req(
      () => http.post(
        Uri.parse('$_baseUrl/incidents/$incidentId/accept'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      timeout: _sosTimeout,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw IncidentException(
        body['message'] as String? ?? 'Gagal menerima misi',
      );
    }
  }

  // ─── Get My Active Response (misi on_scene relawan) ────────────────────────

  static Future<ActiveResponseModel?> getMyActiveResponse({
    required String accessToken,
  }) async {
    try {
      final response = await _req(
        () => http.get(
          Uri.parse('$_baseUrl/incidents/my-active-response'),
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data == null) return null;
      return ActiveResponseModel.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ─── Update Response Location (relawan saat on_scene) ─────────────────────

  static Future<void> updateResponseLocation({
    required String accessToken,
    required String incidentId,
    required double latitude,
    required double longitude,
    String? addressDetail,
  }) async {
    try {
      await http
          .put(
            Uri.parse('$_baseUrl/incidents/$incidentId/response-location'),
            headers: _authHeader(accessToken),
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              'address_detail': addressDetail,
            }),
          )
          .timeout(_defaultTimeout);
    } catch (_) {
      // Silent fail — lokasi diupdate di iterasi berikutnya
    }
  }

  // ─── Volunteer Complete SOS (Upload Proof) ───────────────────────────────

  static Future<void> volunteerCompleteSOS({
    required String accessToken,
    required String incidentId,
    required File photoFile,
  }) async {
    final uri = Uri.parse('$_baseUrl/incidents/$incidentId/volunteer-complete');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken';

    if (photoFile.existsSync()) {
      request.files.add(
        await http.MultipartFile.fromPath('photo', photoFile.path),
      );
    } else {
      throw IncidentException('File foto tidak ditemukan');
    }

    try {
      final response = await request.send().timeout(_defaultTimeout);
      if (response.statusCode != 200) {
        final respStr = await response.stream.bytesToString();
        final body = jsonDecode(respStr) as Map<String, dynamic>;
        throw IncidentException(
          body['message'] as String? ?? 'Gagal mengunggah bukti',
        );
      }
    } catch (e) {
      if (e is IncidentException) rethrow;
      throw IncidentException('Terjadi kesalahan saat mengunggah bukti');
    }
  }

  // ─── Create Report (Jalur B - Laporan Warga) ─────────────────────────────

  static Future<void> createReport({
    required String accessToken,
    required String incidentType,
    required String urgency,
    required double latitude,
    required double longitude,
    String? description,
    String? photoUrl,
    String? audioUrl,
  }) async {
    final response = await _req(
      () => http.post(
        Uri.parse('$_baseUrl/reports'),
        headers: _authHeader(accessToken),
        body: jsonEncode({
          'incident_type': incidentType,
          'urgency': urgency,
          'latitude': latitude,
          'longitude': longitude,
          'description': description,
          'photo_url': photoUrl,
          'audio_url': audioUrl,
        }),
      ),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw IncidentException(
        body['message'] as String? ?? 'Gagal mengirim laporan',
      );
    }
  }
}

// ─── Data Classes ─────────────────────────────────────────────────────────────

class TriggerSOSResult {
  final String incidentId;
  final String status;
  final String message;

  const TriggerSOSResult({
    required this.incidentId,
    required this.status,
    required this.message,
  });

  factory TriggerSOSResult.fromJson(Map<String, dynamic> json) =>
      TriggerSOSResult(
        incidentId: json['incident_id'] as String,
        status: json['status'] as String,
        message: json['message'] as String? ?? '',
      );
}

class VolunteerLocation {
  final String name;
  final double latitude;
  final double longitude;

  const VolunteerLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory VolunteerLocation.fromJson(Map<String, dynamic> json) =>
      VolunteerLocation(
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

class ActiveIncident {
  final String incidentId;
  final String status;
  final String incidentType;
  final double latitude;
  final double longitude;
  final String createdAt;
  final String updatedAt;
  final String reporterTrustLabel;
  final String? agencyStatus;
  final String? handledByAgencyId;
  final String? agencyName;
  final String? volunteerResponseStatus;
  final List<String> volunteerNames;
  final List<VolunteerLocation> volunteerLocations;

  const ActiveIncident({
    required this.incidentId,
    required this.status,
    required this.incidentType,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    String? updatedAt,
    this.reporterTrustLabel = 'standard',
    this.agencyStatus,
    this.handledByAgencyId,
    this.agencyName,
    this.volunteerResponseStatus,
    this.volunteerNames = const [],
    this.volunteerLocations = const [],
  }) : updatedAt = updatedAt ?? createdAt;

  factory ActiveIncident.fromJson(Map<String, dynamic> json) => ActiveIncident(
    incidentId: json['incident_id'] as String? ?? json['id'] as String,
    status: json['status'] as String,
    incidentType: json['incident_type'] as String? ?? 'unknown',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    createdAt: json['created_at'] as String,
    updatedAt: json['updated_at'] as String?,
    reporterTrustLabel: json['reporter_trust_label'] as String? ?? 'standard',
    agencyStatus: json['agency_status'] as String?,
    handledByAgencyId: json['handled_by_agency_id'] as String?,
    agencyName: json['agency_name'] as String?,
    volunteerResponseStatus: json['volunteer_response_status'] as String?,
    volunteerNames:
        (json['volunteer_names'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    volunteerLocations:
        (json['volunteer_locations'] as List<dynamic>?)
            ?.map((e) => VolunteerLocation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  /// Apakah instansi sedang aktif menangani SOS ini.
  bool get isHandledByAgency => agencyStatus == 'handling';

  /// Apakah relawan sedang aktif menangani SOS ini.
  bool get isHandledByVolunteer =>
      volunteerResponseStatus == 'on_scene' ||
      volunteerResponseStatus == 'en_route' ||
      volunteerResponseStatus == 'waiting_review';

  /// True jika ada siapapun yang sudah merespons (instansi atau relawan).
  bool get isBeingHandled => isHandledByAgency || isHandledByVolunteer;
}

// ─── NearbyIncident ───────────────────────────────────────────────────────────

class NearbyIncident {
  final String id;
  final String incidentType;
  final String status;
  final double latitude;
  final double longitude;
  final String? addressDetail;
  final String trustLabel;
  final String createdAt;
  final double distanceKm;
  final List<String> photoPaths;
  final String? audioPath;

  const NearbyIncident({
    required this.id,
    required this.incidentType,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.addressDetail,
    this.trustLabel = 'standard',
    required this.createdAt,
    this.distanceKm = 0.0,
    this.photoPaths = const [],
    this.audioPath,
  });

  factory NearbyIncident.fromJson(Map<String, dynamic> json) => NearbyIncident(
    id: json['id'] as String,
    incidentType: json['incident_type'] as String? ?? 'unknown',
    status: json['status'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    addressDetail: json['address_detail'] as String?,
    trustLabel: json['reporter_trust_label'] as String? ?? 'standard',
    createdAt: json['created_at'] as String,
    distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
    photoPaths:
        (json['photo_paths'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    audioPath: json['audio_path'] as String?,
  );

  /// Menghitung waktu sejak insiden dilaporkan (timeAgo).
  String get timeAgo {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      return '${diff.inDays} hari lalu';
    } catch (_) {
      return '';
    }
  }

  /// Label tipe insiden dalam Bahasa Indonesia.
  String get typeLabel {
    const labels = {
      'medical': 'Medis / Kesehatan',
      'fire': 'Kebakaran',
      'crime': 'Kejahatan',
      'rescue': 'SAR / Penyelamatan',
      'accident': 'Kecelakaan',
      'disaster': 'Bencana Alam',
      'general': 'Umum',
      'unknown': 'Tidak Diketahui',
    };
    return labels[incidentType] ?? incidentType;
  }

  /// Ikon tipe insiden
  String get typeEmoji {
    const emojis = {
      'medical': '🚑',
      'fire': '🔥',
      'crime': '🚨',
      'rescue': '🆘',
      'accident': '🚗',
      'disaster': '🌊',
      'general': '⚠️',
    };
    return emojis[incidentType] ?? '⚠️';
  }

  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

// ─── MissionHistory ───────────────────────────────────────────────────────────

class MissionHistory {
  final String id;
  final String incidentType;
  final String status;
  final String responseStatus;
  final String? addressDetail;
  final String acceptedAt;
  final int xpEarned;

  const MissionHistory({
    required this.id,
    required this.incidentType,
    required this.status,
    required this.responseStatus,
    this.addressDetail,
    required this.acceptedAt,
    this.xpEarned = 0,
  });

  factory MissionHistory.fromJson(Map<String, dynamic> json) => MissionHistory(
    id: json['id'] as String,
    incidentType: json['incident_type'] as String,
    status: json['status'] as String,
    responseStatus: json['response_status'] as String,
    addressDetail: json['address_detail'] as String?,
    acceptedAt: json['accepted_at'] as String,
    xpEarned: json['xp_earned'] as int? ?? 0,
  );
}

// ─── Exceptions ───────────────────────────────────────────────────────────────

class IncidentException implements Exception {
  final String message;
  const IncidentException(this.message);
  @override
  String toString() => message;
}

/// Dilempar saat user mencoba kirim SOS tapi akunnya dibanned.
class SOSBannedException implements Exception {
  final String message;
  const SOSBannedException(this.message);
  @override
  String toString() => message;
}

/// Dilempar saat terjadi race condition (misal instansi sudah menyelesaikan SOS saat user membatalkan)
class SOSConflictException implements Exception {
  final String message;
  const SOSConflictException(this.message);
  @override
  String toString() => message;
}

// ─── ActiveResponseModel ──────────────────────────────────────────────────────

class ActiveResponseModel {
  final String responseId;
  final String incidentId;
  final String incidentType;
  final String status;
  final double reporterLatitude;
  final double reporterLongitude;
  final String? addressDetail;
  final String acceptedAt;

  const ActiveResponseModel({
    required this.responseId,
    required this.incidentId,
    required this.incidentType,
    required this.status,
    required this.reporterLatitude,
    required this.reporterLongitude,
    this.addressDetail,
    required this.acceptedAt,
  });

  factory ActiveResponseModel.fromJson(Map<String, dynamic> json) =>
      ActiveResponseModel(
        responseId: json['response_id'] as String,
        incidentId: json['incident_id'] as String,
        incidentType: json['incident_type'] as String? ?? 'unknown',
        status: json['status'] as String,
        reporterLatitude: (json['reporter_latitude'] as num).toDouble(),
        reporterLongitude: (json['reporter_longitude'] as num).toDouble(),
        addressDetail: json['address_detail'] as String?,
        acceptedAt: json['accepted_at'] as String,
      );

  String get typeLabel {
    const labels = {
      'medical': 'Medis / Kesehatan',
      'fire': 'Kebakaran',
      'crime': 'Kejahatan',
      'rescue': 'SAR / Penyelamatan',
      'accident': 'Kecelakaan',
      'disaster': 'Bencana Alam',
      'general': 'Umum',
      'unknown': 'Tidak Diketahui',
    };
    return labels[incidentType] ?? incidentType;
  }
}
