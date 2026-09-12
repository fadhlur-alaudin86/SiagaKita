import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../constants/api_constants.dart';
import '../models/models.dart';
import 'auth_service.dart';

/// Helper untuk generate idempotency key unik per aksi
String _newIdempotencyKey() => const Uuid().v4();

/// Header standar dengan idempotency key (untuk aksi yang mengubah state)
Map<String, String> _headersWithIdempotency(String token) => {
  ...AuthService.headers(token),
  'X-Idempotency-Key': _newIdempotencyKey(),
};

/// Helper untuk eksekusi HTTP dengan auto-retry saat 401 Unauthorized
Future<http.Response> _requestWithRetry(
  String token,
  Future<http.Response> Function(String activeToken) sendFn,
) async {
  final activeToken = await AuthService.getAccessToken() ?? token;
  var resp = await sendFn(activeToken);

  if (resp.statusCode == 401) {
    debugPrint('[ApiService] 401 Unauthorized. Attempting refresh...');
    final refreshed = await AuthService.refreshToken();
    if (refreshed != null) {
      debugPrint('[ApiService] Token refreshed. Retrying request...');
      resp = await sendFn(refreshed);
    }
  }
  return resp;
}

Future<http.Response> _authedGet(
  Uri uri,
  String token, {
  Map<String, String>? headers,
}) {
  return _requestWithRetry(
    token,
    (activeToken) => http.get(
      uri,
      headers: {...AuthService.headers(activeToken), ...?headers},
    ),
  );
}

Future<http.Response> _authedPost(
  Uri uri,
  String token, {
  Map<String, String>? headers,
  Object? body,
  bool withIdempotency = false,
}) {
  return _requestWithRetry(
    token,
    (activeToken) => http.post(
      uri,
      headers: {
        if (withIdempotency)
          ..._headersWithIdempotency(activeToken)
        else
          ...AuthService.headers(activeToken),
        ...?headers,
      },
      body: body,
    ),
  );
}

Future<http.Response> _authedPut(
  Uri uri,
  String token, {
  Map<String, String>? headers,
  Object? body,
  bool withIdempotency = false,
}) {
  return _requestWithRetry(
    token,
    (activeToken) => http.put(
      uri,
      headers: {
        if (withIdempotency)
          ..._headersWithIdempotency(activeToken)
        else
          ...AuthService.headers(activeToken),
        ...?headers,
      },
      body: body,
    ),
  );
}

Future<http.Response> _authedPatch(
  Uri uri,
  String token, {
  Map<String, String>? headers,
  Object? body,
  bool withIdempotency = false,
}) {
  return _requestWithRetry(
    token,
    (activeToken) => http.patch(
      uri,
      headers: {
        if (withIdempotency)
          ..._headersWithIdempotency(activeToken)
        else
          ...AuthService.headers(activeToken),
        ...?headers,
      },
      body: body,
    ),
  );
}

Future<http.Response> _authedDelete(
  Uri uri,
  String token, {
  Map<String, String>? headers,
  Object? body,
  bool withIdempotency = false,
}) {
  return _requestWithRetry(
    token,
    (activeToken) => http.delete(
      uri,
      headers: {
        if (withIdempotency)
          ..._headersWithIdempotency(activeToken)
        else
          ...AuthService.headers(activeToken),
        ...?headers,
      },
      body: body,
    ),
  );
}

Future<http.StreamedResponse> _authedMultipart(
  String token,
  http.MultipartRequest Function(String activeToken) buildReq,
) async {
  final activeToken = await AuthService.getAccessToken() ?? token;
  var streamed = await buildReq(activeToken).send();
  if (streamed.statusCode == 401) {
    final refreshed = await AuthService.refreshToken();
    if (refreshed != null) {
      streamed = await buildReq(refreshed).send();
    }
  }
  return streamed;
}

class IncidentApiService {
  // ─── List semua SOS aktif (instansi view) ─────────────────────────────────

  static Future<List<IncidentModel>> getActiveIncidents(String token) async {
    final resp = await _authedGet(
      Uri.parse(ApiConstants.incidentsAllActive),
      token,
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => IncidentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<IncidentModel>> getHistory(String token) async {
    final resp = await _authedGet(
      Uri.parse(ApiConstants.incidentsAgencyHistory),
      token,
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => IncidentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Detail incident ───────────────────────────────────────────────────────

  static Future<IncidentModel?> getDetail(String token, String id) async {
    final resp = await _authedGet(
      Uri.parse(ApiConstants.incidentDetail(id)),
      token,
    );
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return IncidentModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ─── Mark False Alarm ─────────────────────────────────────────────────────

  static Future<bool> markFalseAlarm(
    String token,
    String id,
    String reason,
  ) async {
    final resp = await _authedPost(
      Uri.parse(ApiConstants.incidentMarkFalseAlarm(id)),
      token,
      withIdempotency: true,
      body: jsonEncode({'reason': reason}),
    );
    debugPrint('markFalseAlarm status: ${resp.statusCode}, body: ${resp.body}');
    return resp.statusCode == 200;
  }

  // ─── Resolve / Handle ───────────────────────────────────────────────────────

  static Future<bool> agencyHandle(String token, String id) async {
    final resp = await _authedPost(
      Uri.parse(ApiConstants.incidentAgencyHandle(id)),
      token,
      withIdempotency: true,
    );
    return resp.statusCode == 200;
  }

  static Future<bool> resolve(String token, String id) async {
    final resp = await _authedPost(
      Uri.parse(ApiConstants.incidentResolve(id)),
      token,
      withIdempotency: true,
    );
    return resp.statusCode == 200;
  }

  // ─── Dispatch & Telemetry ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getNearbyVolunteers(
    String token,
    double lat,
    double lng, {
    double radiusKm = 15.0,
  }) async {
    final resp = await _authedGet(
      Uri.parse(
        ApiConstants.telemetryNearbyVolunteers(lat, lng, radiusKm: radiusKm),
      ),
      token,
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<bool> dispatchBroadcast(
    String token,
    String incidentId,
    List<String> volunteerIds,
  ) async {
    final resp = await _authedPost(
      Uri.parse(ApiConstants.incidentDispatchBroadcast(incidentId)),
      token,
      withIdempotency: true,
      body: jsonEncode({'volunteer_ids': volunteerIds}),
    );
    return resp.statusCode == 200;
  }

  // ─── Reports (Jalur B) ────────────────────────────────────────────────────

  static Future<List<ReportModel>> getReports(
    String token, {
    String? status,
  }) async {
    final uri = Uri.parse(
      ApiConstants.reports,
    ).replace(queryParameters: status != null ? {'status': status} : null);
    final resp = await _authedGet(uri, token);
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<bool> updateReportStatus(
    String token,
    String id,
    String status, {
    int? urgencyLevel,
  }) async {
    final bodyData = <String, dynamic>{'status': status};
    if (urgencyLevel != null) {
      bodyData['urgency_level'] = urgencyLevel;
    }
    final resp = await _authedPatch(
      Uri.parse(ApiConstants.reportStatus(id)),
      token,
      withIdempotency: true,
      body: jsonEncode(bodyData),
    );
    return resp.statusCode == 200;
  }
}

class AdminApiService {
  // ─── KYC Relawan ──────────────────────────────────────────────────────────

  static Future<List<VolunteerModel>> getPendingVolunteers(String token) async {
    try {
      final resp = await _authedGet(
        Uri.parse(ApiConstants.adminVolunteersPending),
        token,
      );
      if (resp.statusCode != 200) return [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => VolunteerModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<({bool ok, String? message})> approveVolunteer(
    String token,
    String id,
  ) async {
    try {
      final resp = await _authedPost(
        Uri.parse(ApiConstants.adminVolunteerApprove(id)),
        token,
        withIdempotency: true,
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg =
          (body?['data'] is Map ? body!['data']['message'] : null) ??
          body?['message'];
      return (ok: resp.statusCode == 200, message: msg?.toString());
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  static Future<({bool ok, String? message})> rejectVolunteer(
    String token,
    String id,
    String reason,
  ) async {
    try {
      final resp = await _authedPost(
        Uri.parse(ApiConstants.adminVolunteerReject(id)),
        token,
        withIdempotency: true,
        body: jsonEncode({'reason': reason}),
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg =
          (body?['data'] is Map ? body!['data']['message'] : null) ??
          body?['message'];
      return (ok: resp.statusCode == 200, message: msg?.toString());
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  // ─── User Management ──────────────────────────────────────────────────────

  static Future<List<UserModel>> getUsers(
    String token, {
    String? role,
    bool? banned,
    bool? highStrike,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (role != null && role.isNotEmpty) queryParams['role'] = role;
    if (banned != null) queryParams['banned'] = banned.toString();
    if (highStrike != null) queryParams['high_strike'] = highStrike.toString();
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse(
      ApiConstants.adminUsers,
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final resp = await _authedGet(uri, token);
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<UserDetailModel?> getUserDetail(String token, String id) async {
    final resp = await _authedGet(
      Uri.parse(ApiConstants.adminUserDetail(id)),
      token,
    );
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return UserDetailModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ─── KYC Warga ────────────────────────────────────────────────────

  static Future<List<WargaKycModel>> getPendingWargaKyc(String token) async {
    final resp = await _authedGet(
      Uri.parse(ApiConstants.adminWargaKycPending),
      token,
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => WargaKycModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<bool> approveWargaKyc(String token, String id) async {
    final resp = await _authedPost(
      Uri.parse(ApiConstants.adminWargaKycApprove(id)),
      token,
    );
    return resp.statusCode == 200;
  }

  static Future<bool> rejectWargaKyc(String token, String id) async {
    final resp = await _authedPost(
      Uri.parse(ApiConstants.adminWargaKycReject(id)),
      token,
    );
    return resp.statusCode == 200;
  }

  static Future<({bool ok, String? message})> banUser(
    String token,
    String id,
    String reason,
    int days,
  ) async {
    try {
      final resp = await _authedPost(
        Uri.parse(ApiConstants.adminUserBan(id)),
        token,
        body: jsonEncode({'reason': reason, 'days': days}),
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg =
          (body?['data'] is Map ? body!['data']['message'] : null) ??
          body?['message'];
      return (ok: resp.statusCode == 200, message: msg?.toString());
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  static Future<({bool ok, String? message})> unbanUser(
    String token,
    String id,
  ) async {
    try {
      final resp = await _authedPost(
        Uri.parse(ApiConstants.adminUserUnban(id)),
        token,
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg =
          (body?['data'] is Map ? body!['data']['message'] : null) ??
          body?['message'];
      return (ok: resp.statusCode == 200, message: msg?.toString());
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  static Future<({bool ok, String? message})> resetStrike(
    String token,
    String id,
  ) async {
    try {
      final resp = await _authedDelete(
        Uri.parse(ApiConstants.adminUserResetStrike(id)),
        token,
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg =
          (body?['data'] is Map ? body!['data']['message'] : null) ??
          body?['message'];
      return (ok: resp.statusCode == 200, message: msg?.toString());
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  // ─── Agencies & Admins ────────────────────────────────────────────────────

  static Future<List<AgencyModel>> getAgencies(String token) async {
    final resp = await _authedGet(Uri.parse(ApiConstants.adminAgencies), token);
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AgencyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<AdminModel>> getAdmins(String token) async {
    final resp = await _authedGet(Uri.parse(ApiConstants.adminAdmins), token);
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AdminModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Ranks (Gamifikasi) ───────────────────────────────────────────────────

  static Future<List<RankModel>> getRanks(String token) async {
    final resp = await _authedGet(Uri.parse(ApiConstants.adminRanks), token);
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => RankModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<({bool ok, String? message})> createRank(
    String token,
    RankModel rank,
  ) async {
    try {
      final resp = await _authedPost(
        Uri.parse(ApiConstants.adminRanks),
        token,
        body: jsonEncode(rank.toJson()),
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg =
          (body?['data'] is Map ? body!['data']['message'] : null) ??
          body?['message'];
      return (
        ok: resp.statusCode == 200 || resp.statusCode == 201,
        message: msg?.toString(),
      );
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  static Future<({bool ok, String? message})> updateRank(
    String token,
    RankModel rank,
  ) async {
    try {
      final resp = await _authedPut(
        Uri.parse(ApiConstants.adminRankDetail(rank.id)),
        token,
        body: jsonEncode(rank.toJson()),
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg =
          (body?['data'] is Map ? body!['data']['message'] : null) ??
          body?['message'];
      return (ok: resp.statusCode == 200, message: msg?.toString());
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  static Future<({bool ok, String? message})> deleteRank(
    String token,
    String id,
  ) async {
    try {
      final resp = await _authedDelete(
        Uri.parse(ApiConstants.adminRankDetail(id)),
        token,
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg =
          (body?['data'] is Map ? body!['data']['message'] : null) ??
          body?['message'];
      return (ok: resp.statusCode == 200, message: msg?.toString());
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  // ─── Badges (Gamifikasi) ──────────────────────────────────────────────────

  static Future<List<BadgeModel>> getBadges(String token) async {
    final resp = await _authedGet(
      Uri.parse('${ApiConstants.baseUrl}/admin/badges'),
      token,
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => BadgeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<bool> createBadge(
    String token,
    String name,
    String desc,
    List<int>? fileBytes,
    String? fileName, {
    String badgeCode = 'general',
    int level = 1,
    int threshold = 1,
  }) async {
    final resp = await _authedMultipart(token, (activeToken) {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/admin/badges'),
      );
      req.headers.addAll(AuthService.headers(activeToken));
      req.fields['badge_code'] = badgeCode;
      req.fields['badge_name'] = name;
      req.fields['level'] = level.toString();
      req.fields['threshold'] = threshold.toString();
      req.fields['description'] = desc;

      if (fileBytes != null && fileName != null) {
        req.files.add(
          http.MultipartFile.fromBytes('icon', fileBytes, filename: fileName),
        );
      }
      return req;
    });
    return resp.statusCode == 200 || resp.statusCode == 201;
  }

  static Future<bool> updateBadge(
    String token,
    String id,
    String name,
    String desc,
    String existingIconUrl,
    List<int>? fileBytes,
    String? fileName, {
    String badgeCode = 'general',
    int level = 1,
    int threshold = 1,
  }) async {
    final resp = await _authedMultipart(token, (activeToken) {
      final req = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiConstants.baseUrl}/admin/badges/$id'),
      );
      req.headers.addAll(AuthService.headers(activeToken));
      req.fields['badge_code'] = badgeCode;
      req.fields['badge_name'] = name;
      req.fields['level'] = level.toString();
      req.fields['threshold'] = threshold.toString();
      req.fields['description'] = desc;
      req.fields['icon_url'] = existingIconUrl;

      if (fileBytes != null && fileName != null) {
        req.files.add(
          http.MultipartFile.fromBytes('icon', fileBytes, filename: fileName),
        );
      }
      return req;
    });
    return resp.statusCode == 200;
  }

  static Future<bool> deleteBadge(String token, String id) async {
    final resp = await _authedDelete(
      Uri.parse('${ApiConstants.baseUrl}/admin/badges/$id'),
      token,
    );
    return resp.statusCode == 200;
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  static Future<StatsModel?> getStats(
    String token, {
    String period = 'month',
  }) async {
    try {
      final uri = Uri.parse(
        ApiConstants.adminStats,
      ).replace(queryParameters: {'period': period});
      final resp = await _authedGet(uri, token);
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return StatsModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}

class AgencyApiService {
  // ─── Personil ─────────────────────────────────────────────────────────────

  static Future<bool> createPersonnel(
    String token,
    String fullName,
    String email,
    String password,
    String badgeNumber,
  ) async {
    final resp = await _authedPost(
      Uri.parse(ApiConstants.agencyPersonnels),
      token,
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        'badge_number': badgeNumber,
      }),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Gagal membuat personil');
    }
    return true;
  }

  // ─── Profile ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProfile(String token) async {
    final resp = await _authedGet(Uri.parse(ApiConstants.agencyMe), token);
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    return null;
  }
}
