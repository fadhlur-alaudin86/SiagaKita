import 'package:flutter/foundation.dart';

// Enum untuk mendefinisikan 4 role pengguna SiagaKita
enum UserRole {
  masyarakat, // Masyarakat umum
  relawan, // Relawan terverifikasi
}

// Model data pengguna yang sedang login
class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  // New properties for profile & volunteer features
  final String? nik;
  final String? phoneNumber;
  final bool isPhoneVerified;
  final String? birthDate; // format: DD-MM-YYYY or YYYY-MM-DD
  final String? bio;
  final String? volunteerStatus; // 'none', 'pending', 'approved'
  final String
  nikVerificationStatus; // 'none', 'pending', 'approved', 'rejected'
  final String? profilePhotoUrl; // URL foto selfie KYC (sekaligus foto profil)
  final String? specialization;
  final int volunteerPoints;
  final String volunteerLevel;
  final bool isAvailableForMission;
  final bool isSOSBanned; // ← status blokir SOS dari admin
  final bool isSOSActive; // ← sedang mengirim SOS
  final bool hasActiveMission; // ← sedang menangani misi (untuk relawan)
  final Map<String, dynamic>? medicalData;
  final List<Map<String, dynamic>>? emergencyContacts;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.nik,
    this.phoneNumber,
    this.isPhoneVerified = false,
    this.birthDate,
    this.bio,
    this.volunteerStatus,
    this.nikVerificationStatus = 'none',
    this.profilePhotoUrl,
    this.specialization,
    this.volunteerPoints = 0,
    this.volunteerLevel = 'Pemula',
    this.isAvailableForMission = false,
    this.isSOSBanned = false,
    this.isSOSActive = false,
    this.hasActiveMission = false,
    this.medicalData,
    this.emergencyContacts,
  });

  // Global User State
  static final ValueNotifier<UserModel> currentUser = ValueNotifier(
    const UserModel(id: '', name: '', email: '', role: UserRole.masyarakat),
  );

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? nik,
    String? phoneNumber,
    bool? isPhoneVerified,
    String? birthDate,
    String? bio,
    String? volunteerStatus,
    String? nikVerificationStatus,
    String? profilePhotoUrl,
    String? specialization,
    int? volunteerPoints,
    String? volunteerLevel,
    bool? isAvailableForMission,
    bool? isSOSBanned,
    bool? isSOSActive,
    bool? hasActiveMission,
    Map<String, dynamic>? medicalData,
    List<Map<String, dynamic>>? emergencyContacts,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      nik: nik ?? this.nik,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      birthDate: birthDate ?? this.birthDate,
      bio: bio ?? this.bio,
      volunteerStatus: volunteerStatus ?? this.volunteerStatus,
      nikVerificationStatus:
          nikVerificationStatus ?? this.nikVerificationStatus,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      specialization: specialization ?? this.specialization,
      volunteerPoints: volunteerPoints ?? this.volunteerPoints,
      volunteerLevel: volunteerLevel ?? this.volunteerLevel,
      isAvailableForMission:
          isAvailableForMission ?? this.isAvailableForMission,
      isSOSBanned: isSOSBanned ?? this.isSOSBanned,
      isSOSActive: isSOSActive ?? this.isSOSActive,
      hasActiveMission: hasActiveMission ?? this.hasActiveMission,
      medicalData: medicalData ?? this.medicalData,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }

  /// Menghitung umur berdasarkan birthDate (bisa YYYY-MM-DD atau DD-MM-YYYY)
  int? get age {
    if (birthDate == null || birthDate!.isEmpty) return null;
    try {
      DateTime birth;
      final parts = birthDate!.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          birth = DateTime.parse(birthDate!);
        } else {
          birth = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } else {
        birth = DateTime.parse(birthDate!);
      }

      final today = DateTime.now();
      int calculatedAge = today.year - birth.year;
      if (today.month < birth.month ||
          (today.month == birth.month && today.day < birth.day)) {
        calculatedAge--;
      }
      return calculatedAge;
    } catch (e) {
      return null;
    }
  }

  /// Label role dalam Bahasa Indonesia
  String get roleLabel {
    switch (role) {
      case UserRole.masyarakat:
        return 'Masyarakat Umum';
      case UserRole.relawan:
        return 'Relawan';
    }
  }

  /// Warna badge role
  String get roleColor {
    switch (role) {
      case UserRole.masyarakat:
        return '#18A3FF'; // Biru
      case UserRole.relawan:
        return '#22C55E'; // Hijau
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Map emergency_contacts dari format backend
    List<Map<String, dynamic>>? contacts;
    if (json['emergency_contacts'] != null) {
      final raw = json['emergency_contacts'] as List;
      contacts = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'name': m['contact_name'] ?? m['name'] ?? '',
          'relation': m['relation'] ?? '',
          'phone': m['contact_phone'] ?? m['phone'] ?? '',
        };
      }).toList();
    }
    return UserModel(
      id: json['id'] ?? '',
      name: json['full_name'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      role: _roleFromString(json['role']),
      nik: json['nik'],
      phoneNumber: json['phone_number'],
      isPhoneVerified: json['is_phone_verified'] ?? false,
      birthDate: json['date_of_birth'],
      bio: json['bio'],
      volunteerStatus: json['volunteer_status'] as String?,
      nikVerificationStatus:
          json['nik_verification_status'] as String? ?? 'none',
      profilePhotoUrl: json['profile_photo_url'] as String?,
      specialization: json['specialization'],
      volunteerPoints: () {
        final rep = json['volunteer_reputation'] as Map<String, dynamic>?;
        return (rep?['exp_points'] as int?) ??
            (json['volunteer_points'] as int?) ??
            0;
      }(),
      volunteerLevel: () {
        final rep = json['volunteer_reputation'] as Map<String, dynamic>?;
        final xp =
            (rep?['exp_points'] as int?) ??
            (json['volunteer_points'] as int?) ??
            0;
        return json['volunteer_level'] as String? ?? _levelFromExp(xp);
      }(),
      isAvailableForMission: json['is_available_for_mission'] ?? false,
      isSOSBanned: json['is_sos_banned'] as bool? ?? false,
      isSOSActive: json['is_sos_active'] as bool? ?? false,
      hasActiveMission: json['has_active_mission'] as bool? ?? false,
      medicalData: json['medical_data'] != null
          ? Map<String, dynamic>.from(json['medical_data'])
          : _buildMedicalData(json),
      emergencyContacts: contacts,
    );
  }

  static UserRole _roleFromString(String? role) {
    switch (role) {
      case 'volunteer':
        return UserRole.relawan;
      default:
        return UserRole.masyarakat;
    }
  }

  /// Derivasi level badge dari jumlah XP.
  static String _levelFromExp(int xp) {
    if (xp >= 1500) return 'Ahli';
    if (xp >= 500) return 'Mahir';
    if (xp >= 100) return 'Pejuang';
    return 'Pemula';
  }

  /// Build medicalData map from flat backend profile response.
  static Map<String, dynamic>? _buildMedicalData(Map<String, dynamic> json) {
    final hasData =
        json['blood_type'] != null ||
        json['allergies'] != null ||
        json['medical_conditions'] != null ||
        json['height_cm'] != null ||
        json['weight_kg'] != null ||
        json['domicile'] != null;
    if (!hasData) return null;
    return {
      'blood_type': json['blood_type'],
      'allergies': json['allergies'],
      'medical_history': json['medical_conditions'],
      'height': json['height_cm']?.toString(),
      'weight': json['weight_kg']?.toString(),
      'address': json['domicile'],
    };
  }

  /// Sinkronisasi Data JSON untuk dikirim ke Backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'phone_number': phoneNumber,
      'birth_date': birthDate,
      'bio': bio,
      'volunteer_status': volunteerStatus,
      'nik_verification_status': nikVerificationStatus,
      'profile_photo_url': profilePhotoUrl,
      'specialization': specialization,
      'volunteer_points': volunteerPoints,
      'volunteer_level': volunteerLevel,
      'is_available_for_mission': isAvailableForMission,
      'is_sos_banned': isSOSBanned,
      'is_sos_active': isSOSActive,
      'has_active_mission': hasActiveMission,
      'medical_data': medicalData,
      'emergency_contacts': emergencyContacts,
    };
  }
}
