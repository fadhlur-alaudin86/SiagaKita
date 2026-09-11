import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita_responder/features/missions/data/models/mission_model.dart';

void main() {
  group('MissionModel Deserialization & Helper Tests', () {
    final sampleJson = {
      'id': 'inc-test-uuid-1',
      'reporter_id': 'user-reporter-uuid-1',
      'reporter_name': 'Ahmad Fauzi',
      'reporter_phone': '081234567890',
      'blood_type': 'O+',
      'allergies': 'Penicillin',
      'incident_type': 'fire',
      'status': 'handled',
      'latitude': -6.2088,
      'longitude': 106.8456,
      'address_detail': 'Jl. Kebon Sirih No. 10, Jakarta Pusat',
      'reporter_trust_label': 'verified',
      'agency_status': 'handling',
      'handled_by_agency_id': 'agency-uuid-damkar',
      'responder_id': 'personnel-officer-1',
      'responder_name': 'Bripka Joko',
      'created_at': '2026-09-11T10:00:00Z',
      'is_nik_verified': true,
      'is_phone_verified': true,
      'photo_paths': [
        'http://localhost:8080/uploads/evidence1.jpg',
        'http://localhost:8080/uploads/evidence2.jpg'
      ],
      'audio_path': 'http://localhost:8080/uploads/evidence.m4a',
    };

    test('Parses JSON accurately', () {
      final mission = MissionModel.fromJson(sampleJson);

      expect(mission.id, equals('inc-test-uuid-1'));
      expect(mission.reporterName, equals('Ahmad Fauzi'));
      expect(mission.incidentType, equals('fire'));
      expect(mission.status, equals('handled'));
      expect(mission.latitude, equals(-6.2088));
      expect(mission.longitude, equals(106.8456));
      expect(mission.photoPaths.length, equals(2));
      expect(mission.audioPath, isNotNull);
      expect(mission.isNikVerified, isTrue);
    });

    test('Identifies handler officer correctly', () {
      final mission = MissionModel.fromJson(sampleJson);

      expect(mission.isHandledBy('personnel-officer-1'), isTrue);
      expect(mission.isHandledBy('other-officer'), isFalse);
      expect(mission.isHandledBy(null), isFalse);
    });

    test('Identifies terminal status properly', () {
      final activeMission = MissionModel.fromJson(sampleJson);
      expect(activeMission.isTerminal, isFalse);

      final resolvedJson = Map<String, dynamic>.from(sampleJson);
      resolvedJson['status'] = 'resolved';
      final resolvedMission = MissionModel.fromJson(resolvedJson);
      expect(resolvedMission.isTerminal, isTrue);

      final canceledJson = Map<String, dynamic>.from(sampleJson);
      canceledJson['status'] = 'canceled';
      final canceledMission = MissionModel.fromJson(canceledJson);
      expect(canceledMission.isTerminal, isTrue);
    });

    test('Calculates distance formatting properly', () {
      final mission = MissionModel.fromJson(sampleJson);

      // Distance from identical position should be formatted as meters
      final distMeters = mission.formattedDistance(-6.2088, 106.8456);
      expect(distMeters, equals('0 m'));

      // Distance from ~10km away
      final distKm = mission.formattedDistance(-6.3000, 106.8456);
      expect(distKm.contains('km'), isTrue);
    });
  });
}
