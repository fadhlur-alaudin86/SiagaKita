// Konfigurasi API untuk desktop app.
// Mendukung multi-environment via --dart-define-from-file (.env.dev atau .env.prod)
// serta fallback backward-compatible ke API_HOST.
class ApiConstants {
  static const String _rawBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _rawWsUrl = String.fromEnvironment('WS_BASE_URL');
  static const String _rawHost = String.fromEnvironment('API_HOST');

  static const String _fallbackHost = _rawHost == '' ? 'localhost' : _rawHost;

  static const String baseUrl = _rawBaseUrl != ''
      ? _rawBaseUrl
      : 'http://$_fallbackHost:8080/api/v1';

  static const String wsUrl = _rawWsUrl != ''
      ? _rawWsUrl
      : 'ws://$_fallbackHost:8081/v1/ws/connect';

  // Auth
  static const String login = '$baseUrl/auth/console/login';

  // Incidents
  static const String incidents = '$baseUrl/incidents';
  static const String incidentsAllActive = '$baseUrl/incidents/all-active';
  static const String incidentsAgencyHistory =
      '$baseUrl/incidents/agency/history';
  static String incidentDetail(String id) => '$baseUrl/incidents/$id';
  static String incidentMarkFalseAlarm(String id) =>
      '$baseUrl/incidents/$id/mark-false-alarm';
  static String incidentResolve(String id) =>
      '$baseUrl/incidents/$id/agency-resolve';
  static String incidentAgencyHandle(String id) =>
      '$baseUrl/incidents/$id/agency-handle';
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
  static String adminUserDetail(String id) => '$baseUrl/admin/users/$id/detail';
  static const String adminWargaKycPending = '$baseUrl/admin/users/kyc/warga';
  static String adminWargaKycApprove(String id) =>
      '$baseUrl/admin/users/kyc/warga/$id/approve';
  static String adminWargaKycReject(String id) =>
      '$baseUrl/admin/users/kyc/warga/$id/reject';
  static String adminUserBan(String id) => '$baseUrl/admin/users/$id/ban';
  static String adminUserUnban(String id) => '$baseUrl/admin/users/$id/unban';
  static String adminUserResetStrike(String id) =>
      '$baseUrl/admin/users/$id/strike';
  static const String adminRanks = '$baseUrl/admin/ranks';
  static String adminRankDetail(String id) => '$baseUrl/admin/ranks/$id';
  static const String adminStats = '$baseUrl/admin/stats';
}
