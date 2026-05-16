import 'package:intl/intl.dart';

// ─── Incident (SOS Darurat - Jalur A) ─────────────────────────────────────────

class IncidentModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String? reporterPhone;
  final String? bloodType;
  final String? allergies;
  final String incidentType;
  final String status;
  final String? agencyStatus;
  final String? handledByAgencyId;
  final String? volunteerResponseStatus;
  final double latitude;
  final double longitude;
  final String trustLabel; // 'verified' | 'standard' | 'unverified'
  final String? addressDetail;
  final bool isNikVerified;
  final bool isPhoneVerified;
  final String? dob;
  final String? domicile;
  final String? bio;
  final String? emergencyContact;
  final List<String> photoPaths;
  final String? audioPath;
  final DateTime createdAt;
  final DateTime updatedAt; // timestamp terakhir update lokasi
  final DateTime? completedAt;

  const IncidentModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    this.reporterPhone,
    this.bloodType,
    this.allergies,
    required this.incidentType,
    required this.status,
    this.agencyStatus,
    this.handledByAgencyId,
    this.volunteerResponseStatus,
    required this.latitude,
    required this.longitude,
    required this.trustLabel,
    this.addressDetail,
    this.isNikVerified = false,
    this.isPhoneVerified = false,
    this.dob,
    this.domicile,
    this.bio,
    this.emergencyContact,
    this.photoPaths = const [],
    this.audioPath,
    required this.createdAt,
    DateTime? updatedAt,
    this.completedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  factory IncidentModel.fromJson(Map<String, dynamic> json) => IncidentModel(
    // Handle kedua format: REST pakai 'id', WS payload pakai 'incident_id'
    id: (json['id'] ?? json['incident_id'] ?? '') as String,
    reporterId: json['reporter_id'] as String? ?? '',
    reporterName: json['reporter_name'] as String? ?? 'Tidak diketahui',
    reporterPhone: json['reporter_phone'] as String?,
    bloodType: json['blood_type'] as String?,
    allergies: json['allergies'] as String?,
    incidentType: json['incident_type'] as String? ?? 'unknown',
    status: json['status'] as String? ?? 'broadcasting',
    agencyStatus: json['agency_status'] as String?,
    handledByAgencyId: json['handled_by_agency_id'] as String?,
    volunteerResponseStatus: json['volunteer_response_status'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    trustLabel: json['reporter_trust_label'] as String? ?? 'standard',
    addressDetail: json['address_detail'] as String?,
    isNikVerified: json['is_nik_verified'] as bool? ?? false,
    isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
    dob: json['reporter_dob'] as String?,
    domicile: json['reporter_domicile'] as String?,
    bio: json['reporter_bio'] as String?,
    emergencyContact: json['reporter_emergency_contact'] as String?,
    photoPaths:
        (json['photo_paths'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    audioPath: json['audio_path'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String)
        : null,
    completedAt: json['completed_at'] != null
        ? DateTime.tryParse(json['completed_at'] as String)
        : null,
  );

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    return '${diff.inHours} jam lalu';
  }

  /// Online jika lokasi diperbarui dalam 30 detik terakhir.
  bool get isOnline => DateTime.now().difference(updatedAt).inSeconds <= 30;

  /// Label waktu update lokasi terakhir (HH:mm:ss).
  String get lastUpdateLabel {
    final local = updatedAt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get formattedTime => DateFormat('HH:mm').format(createdAt.toLocal());

  String get typeLabel => switch (incidentType) {
    'fire' => 'Kebakaran',
    'medical' => 'Medis',
    'crime' => 'Kriminalitas',
    'rescue' => 'Penyelamatan',
    'accident' => 'Kecelakaan',
    'disaster' => 'Bencana Alam',
    'general' => 'Umum',
    _ => 'Tidak diketahui',
  };

  bool get isActive =>
      status == 'broadcasting' ||
      status == 'grace_period' ||
      status == 'active';

  String get typeLabelId {
    return switch (incidentType) {
      'medical' => 'Medis',
      'fire' => 'Kebakaran',
      'rescue' => 'Penyelamatan',
      'crime' => 'Kriminalitas',
      'accident' => 'Kecelakaan',
      'disaster' => 'Bencana Alam',
      'general' => 'Umum',
      _ => 'Tidak diketahui',
    };
  }

  String get statusLabelId {
    return switch (status) {
      'grace_period' => 'Masa Tenggang',
      'broadcasting' => 'Disiarkan',
      'handled' => 'Ditangani',
      'resolved' => 'Selesai',
      'false_alarm' => 'Alarm Palsu',
      'canceled' => 'Dibatalkan',
      _ => status,
    };
  }

  IncidentModel copyWith({
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
  }) {
    return IncidentModel(
      id: id,
      reporterId: reporterId,
      reporterName: reporterName,
      reporterPhone: reporterPhone,
      bloodType: bloodType,
      allergies: allergies,
      incidentType: incidentType,
      status: status,
      agencyStatus: agencyStatus,
      handledByAgencyId: handledByAgencyId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      trustLabel: trustLabel,
      addressDetail: addressDetail,
      isNikVerified: isNikVerified,
      isPhoneVerified: isPhoneVerified,
      dob: dob,
      domicile: domicile,
      bio: bio,
      emergencyContact: emergencyContact,
      photoPaths: photoPaths,
      audioPath: audioPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt,
    );
  }
}

// ─── Report (Laporan Warga - Jalur B) ─────────────────────────────────────────

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String incidentType;
  final String urgency; // 'low' | 'medium' | 'high' (string dari backend)
  final int? urgencyLevel; // 0=low, 1=medium, 2=high (int dari backend)
  final double latitude;
  final double longitude;
  final String? addressDetail;
  final String? description;
  final List<String> photoPaths;
  final String? audioPath;
  final String status; // 'sent' | 'handled' | 'resolved' | 'rejected'
  final DateTime createdAt;
  final DateTime? completedAt;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.incidentType,
    required this.urgency,
    this.urgencyLevel,
    required this.latitude,
    required this.longitude,
    this.addressDetail,
    this.description,
    this.photoPaths = const [],
    this.audioPath,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    // urgency_level bisa berupa int (dari backend baru)
    // atau 'urgency' string 'low'/'medium'/'high' (dari backend lama)
    final rawLevel = json['urgency_level'];
    int? urgencyLevel;
    if (rawLevel is int) {
      urgencyLevel = rawLevel;
    }
    // derive string urgency from level or field
    final rawUrgency = json['urgency'] as String?;
    String urgency;
    if (urgencyLevel != null) {
      urgency = urgencyLevel == 2
          ? 'high'
          : urgencyLevel == 1
          ? 'medium'
          : 'low';
    } else {
      urgency = rawUrgency ?? 'none';
    }

    return ReportModel(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String? ?? '',
      reporterName: json['reporter_name'] as String? ?? 'Anonim',
      incidentType: json['incident_type'] as String? ?? 'general',
      urgency: urgency,
      urgencyLevel: urgencyLevel,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      addressDetail: json['address_detail'] as String?,
      description: json['description'] as String?,
      photoPaths:
          (json['photo_paths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      audioPath: json['audio_path'] as String?,
      status: json['status'] as String? ?? 'sent',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  // Urgensi hanya bermakna jika sudah diset (bukan 'none')
  bool get hasUrgency =>
      (urgency != 'none' && urgency != 'low') || urgencyLevel != null;

  String get urgencyLabel {
    if (urgencyLevel == null && urgency == 'none') return 'Belum diset';
    return switch (urgency) {
      'high' => 'Tinggi',
      'medium' => 'Sedang',
      'low' => 'Rendah',
      _ => 'Belum diset',
    };
  }

  String get typeLabelId {
    return switch (incidentType) {
      'medical' => 'Medis',
      'fire' => 'Kebakaran',
      'crime' => 'Kriminalitas',
      'accident' => 'Kecelakaan',
      'disaster' => 'Bencana Alam',
      'general' => 'Umum',
      _ => 'Tidak diketahui',
    };
  }

  String get statusLabelId {
    return switch (status) {
      'sent' => 'Terkirim',
      'pending' => 'Menunggu',
      'handled' => 'Ditangani',
      'resolved' => 'Selesai',
      'rejected' => 'Ditolak',
      'canceled' => 'Dibatalkan',
      _ => status,
    };
  }
}

// ─── User ─────────────────────────────────────────────────────────────────────

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? nik;
  final String role;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final String nikVerificationStatus;
  final bool isSOSBanned;
  final int sosStrikeCount;
  final DateTime? lastActiveAt;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.nik,
    required this.role,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.nikVerificationStatus,
    required this.isSOSBanned,
    required this.sosStrikeCount,
    this.lastActiveAt,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String? ?? json['user_id'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phoneNumber: json['phone_number'] as String?,
    nik: json['nik'] as String?,
    role: json['role'] as String? ?? 'civilian',
    isEmailVerified: json['is_email_verified'] as bool? ?? false,
    isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
    nikVerificationStatus: json['nik_verification_status'] as String? ?? 'none',
    isSOSBanned: json['is_sos_banned'] as bool? ?? false,
    sosStrikeCount: json['sos_strike_count'] as int? ?? 0,
    lastActiveAt: json['last_active_at'] != null
        ? DateTime.tryParse(json['last_active_at'] as String)
        : null,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );

  String get onlineStatus {
    if (lastActiveAt == null) return 'Offline';
    final diff = DateTime.now().difference(lastActiveAt!);
    if (diff.inSeconds < 60) return 'Online';
    if (diff.inMinutes < 60) {
      return 'Berjalan di latar belakang (${diff.inMinutes} m lalu)';
    }
    if (diff.inHours < 24) {
      return 'Terakhir terlihat pukul ${DateFormat('HH:mm').format(lastActiveAt!.toLocal())}';
    }
    return 'Terlihat ${diff.inDays} hari yang lalu';
  }
}

// ─── Volunteer (KYC) ──────────────────────────────────────────────────────────

/// Satu sertifikat relawan: URL file + tipe spesialisasi.
class VolunteerCert {
  final String url;
  final String type;

  const VolunteerCert({required this.url, required this.type});

  factory VolunteerCert.fromJson(Map<String, dynamic> json) => VolunteerCert(
    url: json['document_url'] as String? ?? '',
    type: json['certificate_type'] as String? ?? 'Sertifikat',
  );
}

class VolunteerModel {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? nik;
  final String? nikPhotoUrl;
  final List<VolunteerCert> certs; // ganti dari certUrls: List<String>
  final String? experience;
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
    required this.certs,
    this.experience,
    required this.kycStatus,
    this.verifiedBy,
    required this.createdAt,
  });

  factory VolunteerModel.fromJson(Map<String, dynamic> json) {
    // Backend mengirim 'certifications' sebagai List<object> dengan
    // 'document_url' dan 'certificate_type'
    final certsData = json['certifications'] as List<dynamic>? ?? [];
    final certs = certsData
        .map((e) => VolunteerCert.fromJson(e as Map<String, dynamic>))
        .where((c) => c.url.isNotEmpty)
        .toList();

    return VolunteerModel(
      id: json['user_id'] as String? ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      nik: json['nik'] as String?,
      nikPhotoUrl: json['kyc_ktp_url'] as String?,
      certs: certs,
      experience: json['volunteer_experience'] as String?,
      kycStatus: json['kyc_status'] as String? ?? 'pending',
      verifiedBy: json['verified_by'] as String?,
      createdAt:
          DateTime.tryParse(json['submitted_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
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

// ─── KYC Warga ───────────────────────────────────────────────────────────────

class WargaKycModel {
  final String userId;
  final String fullName;
  final String email;
  final String nik;
  final String? kycKtpUrl;
  final String? profilePhotoUrl;
  final String nikVerificationStatus;
  final DateTime submittedAt;

  const WargaKycModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.nik,
    this.kycKtpUrl,
    this.profilePhotoUrl,
    required this.nikVerificationStatus,
    required this.submittedAt,
  });

  factory WargaKycModel.fromJson(Map<String, dynamic> json) => WargaKycModel(
    userId: json['user_id'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    nik: json['nik'] as String? ?? '',
    kycKtpUrl: json['kyc_ktp_url'] as String?,
    profilePhotoUrl: json['profile_photo_url'] as String?,
    nikVerificationStatus: json['nik_verification_status'] as String? ?? 'none',
    submittedAt:
        DateTime.tryParse(json['submitted_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

// ─── User Detail (Admin View) ─────────────────────────────────────────────────

class UserDetailModel {
  final String userId;
  final String email;
  final String role;
  final String? fullName;
  final String? phoneNumber;
  final String? nik;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final String nikVerificationStatus;
  final String? kycKtpUrl;
  final String? profilePhotoUrl;
  final String? dateOfBirth;
  final String? bloodType;
  final String? allergies;
  final String? domicile;
  final int sosStrikeCount;
  final bool isSosBanned;
  final DateTime? lastActiveAt;
  final DateTime createdAt;
  final List<SOSHistoryItem> sosHistory;
  final List<ReportHistoryItem> reportHistory;

  const UserDetailModel({
    required this.userId,
    required this.email,
    required this.role,
    this.fullName,
    this.phoneNumber,
    this.nik,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.nikVerificationStatus,
    this.kycKtpUrl,
    this.profilePhotoUrl,
    this.dateOfBirth,
    this.bloodType,
    this.allergies,
    this.domicile,
    required this.sosStrikeCount,
    required this.isSosBanned,
    this.lastActiveAt,
    required this.createdAt,
    required this.sosHistory,
    required this.reportHistory,
  });

  factory UserDetailModel.fromJson(Map<String, dynamic> json) =>
      UserDetailModel(
        userId: json['user_id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        fullName: json['full_name'] as String?,
        phoneNumber: json['phone_number'] as String?,
        nik: json['nik'] as String?,
        isEmailVerified: json['is_email_verified'] as bool? ?? false,
        isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
        nikVerificationStatus:
            json['nik_verification_status'] as String? ?? 'none',
        kycKtpUrl: json['kyc_ktp_url'] as String?,
        profilePhotoUrl: json['profile_photo_url'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        bloodType: json['blood_type'] as String?,
        allergies: json['allergies'] as String?,
        domicile: json['domicile'] as String?,
        sosStrikeCount: json['sos_strike_count'] as int? ?? 0,
        isSosBanned: json['is_sos_banned'] as bool? ?? false,
        lastActiveAt: json['last_active_at'] != null
            ? DateTime.tryParse(json['last_active_at'] as String)
            : null,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        sosHistory: (json['sos_history'] as List<dynamic>? ?? [])
            .map((e) => SOSHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        reportHistory: (json['report_history'] as List<dynamic>? ?? [])
            .map((e) => ReportHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get onlineStatus {
    if (lastActiveAt == null) return 'Offline';
    final diff = DateTime.now().difference(lastActiveAt!);
    if (diff.inSeconds < 60) return 'Online';
    if (diff.inMinutes < 60) {
      return 'Berjalan di latar belakang (${diff.inMinutes} m lalu)';
    }
    if (diff.inHours < 24) {
      return 'Terakhir terlihat pukul ${DateFormat('HH:mm').format(lastActiveAt!.toLocal())}';
    }
    return 'Terlihat ${diff.inDays} hari yang lalu';
  }
}

class SOSHistoryItem {
  final String id;
  final String incidentType;
  final String status;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime? completedAt;

  const SOSHistoryItem({
    required this.id,
    required this.incidentType,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.completedAt,
  });

  factory SOSHistoryItem.fromJson(Map<String, dynamic> json) => SOSHistoryItem(
    id: json['id'] as String? ?? '',
    incidentType: json['incident_type'] as String? ?? '',
    status: json['status'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    completedAt: json['completed_at'] != null
        ? DateTime.tryParse(json['completed_at'] as String)
        : null,
  );
}

class ReportHistoryItem {
  final String id;
  final String incidentType;
  final String status;
  final String? description;
  final DateTime createdAt;

  const ReportHistoryItem({
    required this.id,
    required this.incidentType,
    required this.status,
    this.description,
    required this.createdAt,
  });

  factory ReportHistoryItem.fromJson(Map<String, dynamic> json) =>
      ReportHistoryItem(
        id: json['id'] as String? ?? '',
        incidentType: json['incident_type'] as String? ?? '',
        status: json['status'] as String? ?? '',
        description: json['description'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─── Agency & Admin Listings ──────────────────────────────────────────────────

class AgencyModel {
  final String agencyId;
  final String accountId;
  final String email;
  final String name;
  final String type;
  final String cityCode;
  final String? hotlineNumber;
  final DateTime createdAt;

  const AgencyModel({
    required this.agencyId,
    required this.accountId,
    required this.email,
    required this.name,
    required this.type,
    required this.cityCode,
    this.hotlineNumber,
    required this.createdAt,
  });

  factory AgencyModel.fromJson(Map<String, dynamic> json) => AgencyModel(
    agencyId: json['agency_id'] as String? ?? '',
    accountId: json['account_id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? '',
    cityCode: json['city_code'] as String? ?? '',
    hotlineNumber: json['hotline_number'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );

  String get typeLabel => switch (type) {
    'police' => 'Polisi',
    'medical' => 'Medis/Ambulans',
    'fire' => 'Pemadam Kebakaran',
    'sar' => 'SAR',
    _ => type.toUpperCase(),
  };
}

class AdminModel {
  final String userId;
  final String email;
  final String role;
  final String? fullName;
  final String? createdBy;
  final DateTime createdAt;

  const AdminModel({
    required this.userId,
    required this.email,
    required this.role,
    this.fullName,
    this.createdBy,
    required this.createdAt,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) => AdminModel(
    userId: json['user_id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'admin',
    fullName: json['full_name'] as String?,
    createdBy: json['created_by'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

class BadgeModel {
  final String id;
  final String badgeName;
  final String description;
  final String iconUrl;
  final DateTime createdAt;

  const BadgeModel({
    required this.id,
    required this.badgeName,
    required this.description,
    required this.iconUrl,
    required this.createdAt,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) => BadgeModel(
    id: json['id'] as String? ?? '',
    badgeName: json['badge_name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    iconUrl: json['icon_url'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );
}
