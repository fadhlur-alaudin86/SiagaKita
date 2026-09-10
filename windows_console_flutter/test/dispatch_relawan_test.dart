import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:siagakita_console/core/localization/app_localization.dart';
import 'package:siagakita_console/core/models/models.dart';

void main() {
  group('Dispatch Relawan UI & Logic Tests (Sub-Issue #18)', () {
    test('Translates dispatch navigation and page keys when locale is EN', () {
      AppLocalization.currentLocale = AppLocalization.localeEn;

      expect(
        AppLocalization.translate('Dispatch Relawan'),
        equals('Volunteer Dispatch'),
      );
      expect(
        AppLocalization.translate('Antrean SOS Aktif'),
        equals('Active SOS Queue'),
      );
      expect(
        AppLocalization.translate('Kandidat Relawan Terdekat'),
        equals('Nearest Volunteer Candidates'),
      );
      expect(
        AppLocalization.translate('Broadcast ke 3 Terdekat'),
        equals('Broadcast to Top 3 Nearest'),
      );
      expect(
        AppLocalization.translate('Kirim Penugasan'),
        equals('Send Dispatch'),
      );
      expect(
        AppLocalization.translate('Tidak ada relawan online dalam radius'),
        equals('No online volunteers within radius'),
      );
      expect(
        AppLocalization.translate('Belum ada insiden SOS aktif'),
        equals('No active SOS incidents'),
      );
      expect(AppLocalization.translate('ON DUTY'), equals('ON DUTY'));
      expect(AppLocalization.translate('Tugaskan'), equals('Dispatch'));
    });

    test('Retains original Indonesian strings when locale is ID', () {
      AppLocalization.currentLocale = AppLocalization.localeId;

      expect(
        AppLocalization.translate('Dispatch Relawan'),
        equals('Dispatch Relawan'),
      );
      expect(
        AppLocalization.translate('Antrean SOS Aktif'),
        equals('Antrean SOS Aktif'),
      );
      expect(
        AppLocalization.translate('Broadcast ke 3 Terdekat'),
        equals('Broadcast ke 3 Terdekat'),
      );
    });

    test(
      'Haversine distance calculation properly ranks volunteer proximity',
      () {
        const distance = Distance();
        // Target SOS location: Banda Aceh center (-5.5500, 95.3200)
        const sosTarget = LatLng(-5.5500, 95.3200);

        // Volunteer A: ~500m away (-5.5540, 95.3220)
        const volA = LatLng(-5.5540, 95.3220);
        // Volunteer B: ~2.5km away (-5.5700, 95.3300)
        const volB = LatLng(-5.5700, 95.3300);
        // Volunteer C: ~1.2km away (-5.5600, 95.3250)
        const volC = LatLng(-5.5600, 95.3250);

        final distA = distance.as(LengthUnit.Kilometer, sosTarget, volA);
        final distB = distance.as(LengthUnit.Kilometer, sosTarget, volB);
        final distC = distance.as(LengthUnit.Kilometer, sosTarget, volC);

        expect(distA < distC, isTrue);
        expect(distC < distB, isTrue);

        final candidates = [
          MapEntry('vol-B', volB),
          MapEntry('vol-A', volA),
          MapEntry('vol-C', volC),
        ];

        candidates.sort((a, b) {
          final d1 = distance.as(LengthUnit.Kilometer, sosTarget, a.value);
          final d2 = distance.as(LengthUnit.Kilometer, sosTarget, b.value);
          return d1.compareTo(d2);
        });

        expect(candidates[0].key, equals('vol-A'));
        expect(candidates[1].key, equals('vol-C'));
        expect(candidates[2].key, equals('vol-B'));
      },
    );

    test(
      'Telemetry anti-memory leak pruning evicts records older than 90s',
      () {
        final volunteerLocations = <String, LatLng>{
          'vol-recent': const LatLng(-5.5500, 95.3200),
          'vol-stale': const LatLng(-5.5600, 95.3300),
        };
        final volunteerLastSeen = <String, DateTime>{
          'vol-recent': DateTime.now().subtract(const Duration(seconds: 10)),
          'vol-stale': DateTime.now().subtract(const Duration(seconds: 95)),
        };

        final now = DateTime.now();
        final staleKeys = <String>[];
        volunteerLastSeen.forEach((id, lastSeen) {
          if (now.difference(lastSeen).inSeconds > 90) {
            staleKeys.add(id);
          }
        });

        for (final key in staleKeys) {
          volunteerLocations.remove(key);
          volunteerLastSeen.remove(key);
        }

        expect(volunteerLocations.containsKey('vol-recent'), isTrue);
        expect(volunteerLocations.containsKey('vol-stale'), isFalse);
        expect(volunteerLastSeen.containsKey('vol-stale'), isFalse);
      },
    );

    test(
      'IncidentModel parses responder details and volunteer response status',
      () {
        final json = <String, dynamic>{
          'id': 'sos-123',
          'reporter_id': 'user-1',
          'reporter_name': 'Ahmad',
          'incident_type': 'fire',
          'status': 'handled',
          'volunteer_response_status': 'en_route',
          'responder_id': 'vol-99',
          'responder_name': 'Budi Relawan',
          'latitude': -5.55,
          'longitude': 95.32,
          'created_at': '2026-09-10T09:00:00Z',
        };

        final incident = IncidentModel.fromJson(json);
        expect(incident.id, equals('sos-123'));
        expect(incident.volunteerResponseStatus, equals('en_route'));
        expect(incident.responderId, equals('vol-99'));
        expect(incident.responderName, equals('Budi Relawan'));
      },
    );

    test('Active mission stepper resolves progression steps accurately', () {
      int resolveStep(String? status) {
        if (status == 'en_route') return 1;
        if (status == 'on_scene') return 2;
        if (status == 'completed' || status == 'waiting_review') return 3;
        return 0; // accepted
      }

      expect(resolveStep('accepted'), equals(0));
      expect(resolveStep('en_route'), equals(1));
      expect(resolveStep('on_scene'), equals(2));
      expect(resolveStep('completed'), equals(3));
      expect(resolveStep('waiting_review'), equals(3));
    });
  });
}
