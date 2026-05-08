import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../models/models.dart';
import 'auth_service.dart';

class IncidentApiService {
  // ─── List semua SOS aktif (instansi view) ─────────────────────────────────

  static Future<List<IncidentModel>> getActiveIncidents(String token) async {
    final resp = await http.get(
      Uri.parse(ApiConstants.incidentsAllActive),
      headers: AuthService.headers(token),
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
    final resp = await http.get(
      Uri.parse(ApiConstants.incidentDetail(id)),
      headers: AuthService.headers(token),
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
    final resp = await http.post(
      Uri.parse(ApiConstants.incidentMarkFalseAlarm(id)),
      headers: AuthService.headers(token),
      body: jsonEncode({'reason': reason}),
    );
    return resp.statusCode == 200;
  }

  // ─── Resolve ──────────────────────────────────────────────────────────────

  static Future<bool> resolve(String token, String id) async {
    final resp = await http.post(
      Uri.parse(ApiConstants.incidentResolve(id)),
      headers: AuthService.headers(token),
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
    final resp = await http.get(uri, headers: AuthService.headers(token));
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
    String status,
  ) async {
    final resp = await http.patch(
      Uri.parse(ApiConstants.reportStatus(id)),
      headers: AuthService.headers(token),
      body: jsonEncode({'status': status}),
    );
    return resp.statusCode == 200;
  }
}

class AdminApiService {
  // ─── KYC Relawan ──────────────────────────────────────────────────────────

  static Future<List<VolunteerModel>> getPendingVolunteers(String token) async {
    try {
      final resp = await http.get(
        Uri.parse(ApiConstants.adminVolunteersPending),
        headers: AuthService.headers(token),
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

  static Future<bool> approveVolunteer(String token, String id) async {
    final resp = await http.post(
      Uri.parse(ApiConstants.adminVolunteerApprove(id)),
      headers: AuthService.headers(token),
    );
    return resp.statusCode == 200;
  }

  static Future<bool> rejectVolunteer(
    String token,
    String id,
    String reason,
  ) async {
    final resp = await http.post(
      Uri.parse(ApiConstants.adminVolunteerReject(id)),
      headers: AuthService.headers(token),
      body: jsonEncode({'reason': reason}),
    );
    return resp.statusCode == 200;
  }

  // ─── User Management ──────────────────────────────────────────────────────

  static Future<List<UserModel>> getUsers(String token) async {
    final resp = await http.get(
      Uri.parse(ApiConstants.adminUsers),
      headers: AuthService.headers(token),
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<UserDetailModel?> getUserDetail(String token, String id) async {
    final resp = await http.get(
      Uri.parse(ApiConstants.adminUserDetail(id)),
      headers: AuthService.headers(token),
    );
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return UserDetailModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ─── KYC Warga ────────────────────────────────────────────────────────────

  static Future<List<WargaKycModel>> getPendingWargaKyc(String token) async {
    final resp = await http.get(
      Uri.parse(ApiConstants.adminWargaKycPending),
      headers: AuthService.headers(token),
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => WargaKycModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<bool> approveWargaKyc(String token, String id) async {
    final resp = await http.post(
      Uri.parse(ApiConstants.adminWargaKycApprove(id)),
      headers: AuthService.headers(token),
    );
    return resp.statusCode == 200;
  }

  static Future<bool> rejectWargaKyc(String token, String id) async {
    final resp = await http.post(
      Uri.parse(ApiConstants.adminWargaKycReject(id)),
      headers: AuthService.headers(token),
    );
    return resp.statusCode == 200;
  }

  static Future<bool> banUser(String token, String id, String reason, int days) async {
    final resp = await http.post(
      Uri.parse(ApiConstants.adminUserBan(id)),
      headers: AuthService.headers(token),
      body: jsonEncode({'reason': reason, 'days': days}),
    );
    return resp.statusCode == 200;
  }

  static Future<bool> unbanUser(String token, String id) async {
    final resp = await http.post(
      Uri.parse(ApiConstants.adminUserUnban(id)),
      headers: AuthService.headers(token),
    );
    return resp.statusCode == 200;
  }

  static Future<bool> resetStrike(String token, String id) async {
    final resp = await http.delete(
      Uri.parse(ApiConstants.adminUserResetStrike(id)),
      headers: AuthService.headers(token),
    );
    return resp.statusCode == 200;
  }

  // ─── Agencies & Admins ────────────────────────────────────────────────────

  static Future<List<AgencyModel>> getAgencies(String token) async {
    final resp = await http.get(
      Uri.parse(ApiConstants.adminAgencies),
      headers: AuthService.headers(token),
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AgencyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<AdminModel>> getAdmins(String token) async {
    final resp = await http.get(
      Uri.parse(ApiConstants.adminAdmins),
      headers: AuthService.headers(token),
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AdminModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Ranks (Gamifikasi) ───────────────────────────────────────────────────

  static Future<List<RankModel>> getRanks(String token) async {
    final resp = await http.get(
      Uri.parse(ApiConstants.adminRanks),
      headers: AuthService.headers(token),
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => RankModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<bool> createRank(String token, RankModel rank) async {
    final resp = await http.post(
      Uri.parse(ApiConstants.adminRanks),
      headers: AuthService.headers(token),
      body: jsonEncode(rank.toJson()),
    );
    return resp.statusCode == 200 || resp.statusCode == 201;
  }

  static Future<bool> updateRank(String token, RankModel rank) async {
    final resp = await http.put(
      Uri.parse(ApiConstants.adminRankDetail(rank.id)),
      headers: AuthService.headers(token),
      body: jsonEncode(rank.toJson()),
    );
    return resp.statusCode == 200;
  }

  static Future<bool> deleteRank(String token, String id) async {
    final resp = await http.delete(
      Uri.parse(ApiConstants.adminRankDetail(id)),
      headers: AuthService.headers(token),
    );
    return resp.statusCode == 200;
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  static Future<StatsModel> getStats(String token) async {
    final resp = await http.get(
      Uri.parse(ApiConstants.adminStats),
      headers: AuthService.headers(token),
    );
    if (resp.statusCode != 200) return StatsModel.empty();
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return StatsModel.fromJson(body['data'] as Map<String, dynamic>);
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
    final resp = await http.post(
      Uri.parse(ApiConstants.agencyPersonnels),
      headers: AuthService.headers(token),
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
    final resp = await http.get(
      Uri.parse(ApiConstants.agencyMe),
      headers: AuthService.headers(token),
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    return null;
  }
}
