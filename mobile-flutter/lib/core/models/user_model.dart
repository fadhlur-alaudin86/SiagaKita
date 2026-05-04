import 'package:flutter/foundation.dart';

// Enum untuk mendefinisikan 4 role pengguna SiagaKita
enum UserRole {
  masyarakat, // Masyarakat umum
  relawan, // Relawan terverifikasi
  instansi, // Instansi penyelamat (Damkar, BPBD, Polisi, dll)
  admin, // Administrator sistem
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
  final String? specialization;
  final int volunteerPoints;
  final String volunteerLevel;
  final bool isAvailableForMission;
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
    this.specialization,
    this.volunteerPoints = 0,
    this.volunteerLevel = 'Pemula',
    this.isAvailableForMission = false,
    this.medicalData,
    this.emergencyContacts,
  });

  // Global Mock User State (while backend is not ready)
  static final ValueNotifier<UserModel> currentUser = ValueNotifier(
    const UserModel(
      id: 'SK-2983-4412',
      name: 'Budi Santoso',
      email: 'budi@email.com',
      role: UserRole.masyarakat,
      phoneNumber: '081234567890',
      birthDate: '20-05-1998',
      bio:
          'Pemerhati keamanan bencana dan warga aktif dalam sosialisasi tanggap darurat lingkungan.',
      volunteerStatus: 'approved',
      specialization: 'Medis Pertama',
      volunteerPoints: 120,
      volunteerLevel: 'Relawan Madya',
      isAvailableForMission: true,
      medicalData: {
        'blood_type': 'O+',
        'weight': '70',
        'height': '175',
        'allergies': 'Penisilin, Kacang',
        'medical_history': 'Asma Ringan',
        'address':
            'Jl. Cut Nyak Dhien No. 44, Peukan Bada, Kabupaten Aceh Besar, Aceh 23351',
      },
      emergencyContacts: [
        {
          'name': 'Siti Aminah',
          'relation': 'Ibu / Wali',
          'phone': '081234567891',
        },
      ],
    ),
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
    String? specialization,
    int? volunteerPoints,
    String? volunteerLevel,
    bool? isAvailableForMission,
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
      specialization: specialization ?? this.specialization,
      volunteerPoints: volunteerPoints ?? this.volunteerPoints,
      volunteerLevel: volunteerLevel ?? this.volunteerLevel,
      isAvailableForMission:
          isAvailableForMission ?? this.isAvailableForMission,
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
      case UserRole.instansi:
        return 'Instansi Penyelamat';
      case UserRole.admin:
        return 'Administrator';
    }
  }

  /// Warna badge role
  String get roleColor {
    switch (role) {
      case UserRole.masyarakat:
        return '#18A3FF'; // Biru
      case UserRole.relawan:
        return '#22C55E'; // Hijau
      case UserRole.instansi:
        return '#FF7418'; // Oranye
      case UserRole.admin:
        return '#A855F7'; // Ungu
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
      volunteerStatus: json['volunteer_status'],
      specialization: json['specialization'],
      volunteerPoints: json['volunteer_points'] ?? 0,
      volunteerLevel: json['volunteer_level'] ?? 'Pemula',
      isAvailableForMission: json['is_available_for_mission'] ?? false,
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
      case 'admin':
      case 'superadmin':
        return UserRole.admin;
      case 'agency':
      case 'agency_personnel':
        return UserRole.instansi;
      default:
        return UserRole.masyarakat;
    }
  }

  /// Build medicalData map from flat backend profile response.
  static Map<String, dynamic>? _buildMedicalData(Map<String, dynamic> json) {
    final hasData = json['blood_type'] != null ||
        json['allergies'] != null ||
        json['medical_conditions'] != null ||
        json['height_cm'] != null ||
        json['weight_kg'] != null ||
        json['alamat'] != null;
    if (!hasData) return null;
    return {
      'blood_type': json['blood_type'],
      'allergies': json['allergies'],
      'medical_history': json['medical_conditions'],
      'height': json['height_cm']?.toString(),
      'weight': json['weight_kg']?.toString(),
      'address': json['alamat'],
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
      'specialization': specialization,
      'volunteer_points': volunteerPoints,
      'volunteer_level': volunteerLevel,
      'is_available_for_mission': isAvailableForMission,
      'medical_data': medicalData,
      'emergency_contacts': emergencyContacts,
    };
  }
}
