import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';

/// IncidentService menangani API calls untuk SOS incidents (Jalur A)
/// dan laporan warga non-darurat (Jalur B).
class IncidentService {
  static const String _baseUrl = ApiConfig.baseUrl;

  // Timeout: SOS-critical calls pakai 10 detik, regular calls 15 detik
  static const _sosTimeout = Duration(seconds: 10);
  static const _defaultTimeout = Duration(seconds: 15);

  // ─── Helper: request dengan timeout ──────────────────────────────────────

  static Future<http.Response> _req(Future<http.Response> Function() call,
      {Duration? timeout}) async {
    try {
      return await call().timeout(
        timeout ?? _defaultTimeout,
        onTimeout: () =>
            throw IncidentException('Request timeout. Coba lagi.'),
      );
    } on IncidentException {
      rethrow;
    } on SOSBannedException {
      rethrow;
    } catch (_) {
      throw IncidentException('Gagal menghubungi server. Periksa koneksi.');
    }
  }

  static Map<String, String> _authHeader(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  // ─── Trigger SOS (Jalur A) ────────────────────────────────────────────────

  /// Mengirim SOS. Selalu mulai dengan tipe 'unknown'.
  /// Status awal: grace_period. Tipe diupdate via [updateType].
  static Future<TriggerSOSResult> triggerSOS({
    required String accessToken,
    required double latitude,
    required double longitude,
    String triggerMethod = 'user',
  }) async {
    final response = await _req(
      () => http.post(
        Uri.parse('$_baseUrl/incidents/trigger'),
        headers: _authHeader(accessToken),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'trigger_method': triggerMethod,
        }),
      ),
      timeout: _sosTimeout, // SOS harus cepat
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 403) {
      throw SOSBannedException(body['message'] as String? ?? 'Fitur SOS dinonaktifkan');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw IncidentException(body['message'] as String? ?? 'Gagal mengirim SOS');
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
      throw IncidentException(body['message'] as String? ?? 'Gagal update tipe');
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
      // Silent fail — SOS tetap aktif, status update di iterasi berikutnya
    }
  }

  // ─── Cancel SOS ───────────────────────────────────────────────────────────

  static Future<void> cancelSOS({
    required String accessToken,
    required String incidentId,
  }) async {
    final response = await _req(
      () => http.post(
        Uri.parse('$_baseUrl/incidents/$incidentId/cancel'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      timeout: _sosTimeout,
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw IncidentException(body['message'] as String? ?? 'Gagal membatalkan SOS');
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
      // Silent fail — lokasi diupdate di timer interval berikutnya (1 menit)
    }
  }

  // ─── Get Active Incident ──────────────────────────────────────────────────

  static Future<ActiveIncident?> getActive({
    required String accessToken,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/incidents/active'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_defaultTimeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data == null) return null;
      return ActiveIncident.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null; // Silent fail — UI tetap tampil tanpa data aktif
    }
  }

  // ─── Create Report (Jalur B — Laporan Warga) ─────────────────────────────

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
      throw IncidentException(body['message'] as String? ?? 'Gagal mengirim laporan');
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

class ActiveIncident {
  final String incidentId;
  final String status;
  final String incidentType;
  final double latitude;
  final double longitude;
  final String createdAt;
  final String reporterTrustLabel;

  const ActiveIncident({
    required this.incidentId,
    required this.status,
    required this.incidentType,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.reporterTrustLabel = 'standard',
  });

  factory ActiveIncident.fromJson(Map<String, dynamic> json) => ActiveIncident(
        incidentId: json['incident_id'] as String,
        status: json['status'] as String,
        incidentType: json['incident_type'] as String? ?? 'unknown',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        createdAt: json['created_at'] as String,
        reporterTrustLabel:
            json['reporter_trust_label'] as String? ?? 'standard',
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
