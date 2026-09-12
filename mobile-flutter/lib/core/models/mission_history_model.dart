import 'package:flutter/material.dart';

// Purpose: Data model representing a volunteer's emergency mission response history.
// Data & Logic Flow: Deserializes JSON from GET /incidents/missions/history or /my-history into structured MissionHistoryItem instances.
// Key Components: MissionHistoryItem (mission response summary with duration, proof photo, and XP).

class MissionHistoryItem {
  final String id;
  final String incidentType;
  final String status;
  final String responseStatus;
  final String? addressDetail;
  final String acceptedAt;
  final String? completedAt;
  final int? durationMinutes;
  final String? proofPhotoUrl;
  final int xpEarned;

  const MissionHistoryItem({
    required this.id,
    required this.incidentType,
    required this.status,
    required this.responseStatus,
    this.addressDetail,
    required this.acceptedAt,
    this.completedAt,
    this.durationMinutes,
    this.proofPhotoUrl,
    this.xpEarned = 0,
  });

  factory MissionHistoryItem.fromJson(Map<String, dynamic> json) =>
      MissionHistoryItem(
        id: json['id'] as String? ?? '',
        incidentType: json['incident_type'] as String? ?? 'general',
        status: json['status'] as String? ?? '',
        responseStatus: json['response_status'] as String? ?? '',
        addressDetail: json['address_detail'] as String?,
        acceptedAt: json['accepted_at'] as String? ?? '',
        completedAt: json['completed_at'] as String?,
        durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
        proofPhotoUrl: json['proof_photo_url'] as String?,
        xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'incident_type': incidentType,
    'status': status,
    'response_status': responseStatus,
    'address_detail': addressDetail,
    'accepted_at': acceptedAt,
    'completed_at': completedAt,
    'duration_minutes': durationMinutes,
    'proof_photo_url': proofPhotoUrl,
    'xp_earned': xpEarned,
  };

  /// Icon for the incident type
  IconData get typeIcon {
    return switch (incidentType) {
      'medical' => Icons.medical_services,
      'fire' => Icons.local_fire_department,
      'crime' => Icons.local_police,
      'rescue' => Icons.emergency,
      'accident' => Icons.car_crash,
      'disaster' => Icons.flood,
      _ => Icons.warning_amber,
    };
  }

  /// Bracketed code for the incident type
  String get typeCode {
    return switch (incidentType) {
      'medical' => '[Medis]',
      'fire' => '[Kebakaran]',
      'crime' => '[Kriminal]',
      'rescue' => '[SAR]',
      'accident' => '[Kecelakaan]',
      'disaster' => '[Bencana]',
      _ => '[Umum]',
    };
  }

  /// User friendly label for incident type
  String get typeLabel {
    return switch (incidentType) {
      'medical' => 'Medis / Kesehatan',
      'fire' => 'Kebakaran',
      'crime' => 'Kejahatan',
      'rescue' => 'SAR / Penyelamatan',
      'accident' => 'Kecelakaan',
      'disaster' => 'Bencana Alam',
      _ => 'Umum',
    };
  }
}
