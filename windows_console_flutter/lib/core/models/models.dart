import 'package:intl/intl.dart';

// ─── Incident (SOS Darurat — Jalur A) ─────────────────────────────────────────

class IncidentModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String? reporterPhone;
  final String? bloodType;
  final String? allergies;
  final String incidentType;
  final String status;
  final double latitude;
  final double longitude;
  final String trustLabel; // 'verified' | 'standard' | 'unverified'
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const IncidentModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    this.reporterPhone,
    this.bloodType,
    this.allergies,
    required this.incidentType,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.trustLabel,
    required this.createdAt,
    this.resolvedAt,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) => IncidentModel(
    id: json['id'] as String,
    reporterId: json['reporter_id'] as String? ?? '',
    reporterName: json['reporter_name'] as String? ?? 'Tidak diketahui',
    reporterPhone: json['reporter_phone'] as String?,
    bloodType: json['blood_type'] as String?,
    allergies: json['allergies'] as String?,
    incidentType: json['incident_type'] as String? ?? 'unknown',
    status: json['status'] as String? ?? 'broadcasting',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    trustLabel: json['reporter_trust_label'] as String? ?? 'standard',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    resolvedAt: json['resolved_at'] != null
        ? DateTime.tryParse(json['resolved_at'] as String)
        : null,
  );

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    return '${diff.inHours} jam lalu';
  }

  String get formattedTime => DateFormat('HH:mm').format(createdAt.toLocal());

  String get typeLabel => switch (incidentType) {
    'fire' => '🔥 Kebakaran',
    'medical' => '🚑 Medis',
    'crime' => '🔪 Kriminal',
    'rescue' => '💥 Kecelakaan',
    'general' => '📋 Umum',
    _ => '❓ Tidak diketahui',
  };

  bool get isActive =>
      status == 'broadcasting' ||
      status == 'grace_period' ||
      status == 'active';
}

// ─── Report (Laporan Warga — Jalur B) ─────────────────────────────────────────

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String incidentType;
  final String urgency; // 'low' | 'medium' | 'high'
  final double latitude;
  final double longitude;
  final String? description;
  final String? photoUrl;
  final String? audioUrl;
  final String status; // 'pending' | 'reviewed' | 'actioned'
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.incidentType,
    required this.urgency,
    required this.latitude,
    required this.longitude,
    this.description,
    this.photoUrl,
    this.audioUrl,
    required this.status,
    required this.createdAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) => ReportModel(
    id: json['id'] as String,
    reporterId: json['reporter_id'] as String? ?? '',
    reporterName: json['reporter_name'] as String? ?? 'Anonim',
    incidentType: json['incident_type'] as String? ?? 'general',
    urgency: json['urgency'] as String? ?? 'low',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    description: json['description'] as String?,
    photoUrl: json['photo_url'] as String?,
    audioUrl: json['audio_url'] as String?,
    status: json['status'] as String? ?? 'pending',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );

  String get urgencyLabel => switch (urgency) {
    'high' => '🔴 Tinggi',
    'medium' => '🟡 Sedang',
    _ => '🟢 Rendah',
  };
}

// ─── User ─────────────────────────────────────────────────────────────────────

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String role;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isSOSBanned;
  final int sosStrikeCount;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    required this.role,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.isSOSBanned,
    required this.sosStrikeCount,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String? ?? json['user_id'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phoneNumber: json['phone_number'] as String?,
    role: json['role'] as String? ?? 'civilian',
    isEmailVerified: json['is_email_verified'] as bool? ?? false,
    isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
    isSOSBanned: json['is_sos_banned'] as bool? ?? false,
    sosStrikeCount: json['sos_strike_count'] as int? ?? 0,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

// ─── Volunteer (KYC) ──────────────────────────────────────────────────────────

class VolunteerModel {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? nik;
  final String? nikPhotoUrl;
  final List<String> certUrls;
  final String kycStatus; // 'pending' | 'approved' | 'rejected'
  final String? verifiedBy;
  final DateTime createdAt;

  const VolunteerModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.nik,
    this.nikPhotoUrl,
    required this.certUrls,
    required this.kycStatus,
    this.verifiedBy,
    required this.createdAt,
  });

  factory VolunteerModel.fromJson(Map<String, dynamic> json) => VolunteerModel(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phoneNumber: json['phone_number'] as String?,
    nik: json['nik'] as String?,
    nikPhotoUrl: json['nik_photo_url'] as String?,
    certUrls:
        (json['cert_urls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    kycStatus: json['kyc_status'] as String? ?? 'pending',
    verifiedBy: json['verified_by'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

// ─── Rank (Master Gamifikasi) ─────────────────────────────────────────────────

class RankModel {
  final String id;
  final String rankName;
  final int minExp;
  final String iconUrl;

  const RankModel({
    required this.id,
    required this.rankName,
    required this.minExp,
    required this.iconUrl,
  });

  factory RankModel.fromJson(Map<String, dynamic> json) => RankModel(
    id: json['id']?.toString() ?? '',
    rankName: json['rank_name'] as String? ?? '',
    minExp: json['min_exp'] as int? ?? 0,
    iconUrl: json['icon_url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'rank_name': rankName,
    'min_exp': minExp,
    'icon_url': iconUrl,
  };
}

// ─── Stats (Analitik) ─────────────────────────────────────────────────────────

class StatsModel {
  final int totalSOS;
  final int totalResolved;
  final double avgResponseMinutes;
  final double falseAlarmRate;
  final int activeVolunteers;
  final Map<String, int> byType; // {'fire': 12, 'medical': 24, ...}
  final Map<String, int> byStatus; // {'resolved': 80, 'false_alarm': 10, ...}
  final List<Map<String, dynamic>> monthly; // [{month: 'Jan', count: 12}, ...]

  const StatsModel({
    required this.totalSOS,
    required this.totalResolved,
    required this.avgResponseMinutes,
    required this.falseAlarmRate,
    required this.activeVolunteers,
    required this.byType,
    required this.byStatus,
    required this.monthly,
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) => StatsModel(
    totalSOS: json['total_sos'] as int? ?? 0,
    totalResolved: json['total_resolved'] as int? ?? 0,
    avgResponseMinutes: (json['avg_response_minutes'] as num?)?.toDouble() ?? 0,
    falseAlarmRate: (json['false_alarm_rate'] as num?)?.toDouble() ?? 0,
    activeVolunteers: json['active_volunteers'] as int? ?? 0,
    byType: Map<String, int>.from(json['by_type'] as Map? ?? {}),
    byStatus: Map<String, int>.from(json['by_status'] as Map? ?? {}),
    monthly:
        (json['monthly'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
  );

  factory StatsModel.empty() => const StatsModel(
    totalSOS: 0,
    totalResolved: 0,
    avgResponseMinutes: 0,
    falseAlarmRate: 0,
    activeVolunteers: 0,
    byType: {},
    byStatus: {},
    monthly: [],
  );
}
