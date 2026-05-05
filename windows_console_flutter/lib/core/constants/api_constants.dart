// Konfigurasi API untuk desktop app.
// Ganti _host untuk pindah antara local dan production.
class ApiConstants {
  // ── GANTI DI SINI jika server berganti ──────────────────────────────
  static const String _host = '139.59.99.230';
  // ────────────────────────────────────────────────────────────────────

  static const String baseUrl = 'http://$_host:8080/api/v1';
  static const String wsUrl = 'ws://$_host:8081/v1/ws/connect';

  // Auth
  static const String login = '$baseUrl/auth/console/login';

  // Incidents
  static const String incidents = '$baseUrl/incidents';
  static const String incidentsAllActive = '$baseUrl/incidents/all-active';
  static String incidentDetail(String id) => '$baseUrl/incidents/$id';
  static String incidentMarkFalseAlarm(String id) =>
      '$baseUrl/incidents/$id/mark-false-alarm';
  static String incidentResolve(String id) => '$baseUrl/incidents/$id/resolve';
  static String incidentType(String id) => '$baseUrl/incidents/$id/type';

  // Reports (Jalur B)
  static const String reports = '$baseUrl/reports';
  static String reportStatus(String id) => '$baseUrl/reports/$id/status';

  // Agency
  static const String agencyMe = '$baseUrl/agencies/me';
  static const String agencyPersonnels = '$baseUrl/agencies/personnels';

  // Admin
  static const String adminAdmins = '$baseUrl/admin/admins';
  static const String adminAgencies = '$baseUrl/admin/agencies';
  static const String adminVolunteersPending =
      '$baseUrl/admin/volunteers/pending';
  static String adminVolunteerApprove(String id) =>
      '$baseUrl/admin/volunteers/$id/approve';
  static String adminVolunteerReject(String id) =>
      '$baseUrl/admin/volunteers/$id/reject';
  static const String adminUsers = '$baseUrl/admin/users';
  static String adminUserBan(String id) => '$baseUrl/admin/users/$id/ban';
  static String adminUserUnban(String id) => '$baseUrl/admin/users/$id/unban';
  static String adminUserResetStrike(String id) =>
      '$baseUrl/admin/users/$id/strike';
  static const String adminRanks = '$baseUrl/admin/ranks';
  static String adminRankDetail(String id) => '$baseUrl/admin/ranks/$id';
  static const String adminStats = '$baseUrl/admin/stats';
}
