import 'package:geolocator/geolocator.dart';

/// MissionModel represents an assigned or open emergency dispatch for agency field units.
class MissionModel {
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
  final String? addressDetail;
  final String reporterTrustLabel;
  final String? agencyStatus;
  final String? handledByAgencyId;
  final String? responderId;
  final String? responderName;
  final DateTime createdAt;
  final bool isNikVerified;
  final bool isPhoneVerified;
  final List<String> photoPaths;
  final String? audioPath;

  const MissionModel({
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
    this.addressDetail,
    required this.reporterTrustLabel,
    this.agencyStatus,
    this.handledByAgencyId,
    this.responderId,
    this.responderName,
    required this.createdAt,
    required this.isNikVerified,
    required this.isPhoneVerified,
    required this.photoPaths,
    this.audioPath,
  });

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    var rawPhotos = json['photo_paths'];
    List<String> photos = [];
    if (rawPhotos is List) {
      photos = rawPhotos.map((e) => e.toString()).toList();
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (json['created_at'] != null) {
      try {
        parsedCreatedAt = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    return MissionModel(
      id: json['id'] as String? ?? '',
      reporterId: json['reporter_id'] as String? ?? '',
      reporterName: json['reporter_name'] as String? ?? 'Warga (Anonim)',
      reporterPhone: json['reporter_phone'] as String?,
      bloodType: json['blood_type'] as String?,
      allergies: json['allergies'] as String?,
      incidentType: json['incident_type'] as String? ?? 'general',
      status: json['status'] as String? ?? 'broadcasting',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      addressDetail: json['address_detail'] as String?,
      reporterTrustLabel: json['reporter_trust_label'] as String? ?? 'standard',
      agencyStatus: json['agency_status'] as String?,
      handledByAgencyId: json['handled_by_agency_id'] as String?,
      responderId: json['responder_id'] as String?,
      responderName: json['responder_name'] as String?,
      createdAt: parsedCreatedAt,
      isNikVerified: json['is_nik_verified'] == true,
      isPhoneVerified: json['is_phone_verified'] == true,
      photoPaths: photos,
      audioPath: json['audio_path'] as String?,
    );
  }

  bool get isTerminal =>
      status == 'resolved' || status == 'canceled' || status == 'false_alarm';

  bool isHandledBy(String? userId) =>
      userId != null && responderId != null && responderId == userId;

  double distanceInKm(double? currentLat, double? currentLng) {
    if (currentLat == null || currentLng == null) return 0.0;
    final meters = Geolocator.distanceBetween(
      currentLat,
      currentLng,
      latitude,
      longitude,
    );
    return meters / 1000.0;
  }

  String formattedDistance(double? currentLat, double? currentLng) {
    final km = distanceInKm(currentLat, currentLng);
    if (km < 1.0) {
      return '${(km * 1000).toInt()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }
}
