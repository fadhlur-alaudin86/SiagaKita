// Purpose: Unit tests for LocalStorageService verifying Hive offline storage, ring buffer decimation, and SharedPreferences migration.
// Data & Logic Flow: Uses temporary directory for Hive boxes, sets mock SharedPreferences, and asserts CRUD, FIFO capping, decimation, and migration invariants.
// Key Components: LocalStorageServiceTest.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siagakita/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init(storagePath: tempDir.path);
  });

  tearDown(() async {
    await LocalStorageService.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SOS Queue CRUD', () {
    test('savePendingSOS, getPendingSOS, and clearPendingSOS', () async {
      expect(LocalStorageService.getPendingSOS(), isNull);

      await LocalStorageService.savePendingSOS(
        localId: 'local-sos-001',
        lat: -6.200000,
        lng: 106.816666,
        addressDetail: 'Jl. Sudirman No. 1',
      );

      final sos = LocalStorageService.getPendingSOS();
      expect(sos, isNotNull);
      expect(sos!['local_id'], equals('local-sos-001'));
      expect(sos['latitude'], equals(-6.200000));
      expect(sos['longitude'], equals(106.816666));
      expect(sos['address_detail'], equals('Jl. Sudirman No. 1'));

      await LocalStorageService.clearPendingSOS();
      expect(LocalStorageService.getPendingSOS(), isNull);
    });

    test(
      'savePendingCancelSOS, getPendingCancelSOS, and clearPendingCancelSOS',
      () async {
        expect(LocalStorageService.getPendingCancelSOS(), isNull);

        await LocalStorageService.savePendingCancelSOS(
          'incident-to-cancel-123',
        );
        expect(
          LocalStorageService.getPendingCancelSOS(),
          equals('incident-to-cancel-123'),
        );

        await LocalStorageService.clearPendingCancelSOS();
        expect(LocalStorageService.getPendingCancelSOS(), isNull);
      },
    );

    test(
      'savePendingIncidentType, getPendingIncidentType, and clearPendingIncidentType',
      () async {
        expect(LocalStorageService.getPendingIncidentType(), isNull);

        await LocalStorageService.savePendingIncidentType('medical');
        expect(LocalStorageService.getPendingIncidentType(), equals('medical'));

        await LocalStorageService.clearPendingIncidentType();
        expect(LocalStorageService.getPendingIncidentType(), isNull);
      },
    );

    test(
      'saveCooldownEndTime, getCooldownEndTime, and clearCooldownEndTime',
      () async {
        expect(LocalStorageService.getCooldownEndTime(), isNull);

        final targetTime = DateTime.now().add(const Duration(minutes: 5));
        await LocalStorageService.saveCooldownEndTime(targetTime);

        final retrieved = LocalStorageService.getCooldownEndTime();
        expect(retrieved, isNotNull);
        expect(
          retrieved!.difference(targetTime).inSeconds.abs(),
          lessThanOrEqualTo(1),
        );

        await LocalStorageService.clearCooldownEndTime();
        expect(LocalStorageService.getCooldownEndTime(), isNull);
      },
    );
  });

  group('Incident Cache & TTL', () {
    test('caches and retrieves incident feed', () async {
      final sampleFeed = [
        {'id': 'inc-1', 'title': 'Kebakaran'},
        {'id': 'inc-2', 'title': 'Kecelakaan'},
      ];

      await LocalStorageService.cacheIncidents('test_cache_key', sampleFeed);
      final retrieved = LocalStorageService.getCachedIncidents(
        'test_cache_key',
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(2));
      expect(retrieved[0]['id'], equals('inc-1'));
    });

    test('returns null when cached incident feed exceeds maxAge TTL', () async {
      final sampleFeed = [
        {'id': 'expired-inc'},
      ];
      await LocalStorageService.cacheIncidents('expired_key', sampleFeed);

      // Verify normal access
      expect(LocalStorageService.getCachedIncidents('expired_key'), isNotNull);

      // Access with 0 maxAge to simulate expiration
      final expired = LocalStorageService.getCachedIncidents(
        'expired_key',
        maxAge: Duration.zero,
      );
      expect(expired, isNull);
    });

    test('clearIncidentCache removes specific cache key', () async {
      await LocalStorageService.cacheIncidents('key_a', [
        {'id': '1'},
      ]);
      await LocalStorageService.cacheIncidents('key_b', [
        {'id': '2'},
      ]);

      await LocalStorageService.clearIncidentCache('key_a');
      expect(LocalStorageService.getCachedIncidents('key_a'), isNull);
      expect(LocalStorageService.getCachedIncidents('key_b'), isNotNull);
    });
  });

  group('Telemetry Ring Buffer & Decimation', () {
    test('buffers point and applies distance/temporal decimation', () async {
      final t0 = DateTime(2026, 9, 11, 10, 0, 0);

      // 1. Initial point
      final added1 = await LocalStorageService.bufferTelemetryPoint(
        latitude: -6.200000,
        longitude: 106.816666,
        timestamp: t0,
      );
      expect(added1, isTrue);
      expect(LocalStorageService.getTelemetryBuffer().length, equals(1));

      // 2. Insignificant movement (< 15m) within 10s (< 30s) -> Should be skipped
      final added2 = await LocalStorageService.bufferTelemetryPoint(
        latitude: -6.200020, // ~2.2 meters displacement
        longitude: 106.816666,
        timestamp: t0.add(const Duration(seconds: 10)),
      );
      expect(added2, isFalse);
      expect(LocalStorageService.getTelemetryBuffer().length, equals(1));

      // 3. Significant movement (> 15m) within 10s -> Should be accepted
      final added3 = await LocalStorageService.bufferTelemetryPoint(
        latitude: -6.201000, // ~111 meters displacement
        longitude: 106.816666,
        timestamp: t0.add(const Duration(seconds: 15)),
      );
      expect(added3, isTrue);
      expect(LocalStorageService.getTelemetryBuffer().length, equals(2));

      // 4. Little movement (< 15m) but elapsed time >= 30s -> Should be accepted
      final added4 = await LocalStorageService.bufferTelemetryPoint(
        latitude: -6.201010,
        longitude: 106.816666,
        timestamp: t0.add(const Duration(seconds: 50)),
      );
      expect(added4, isTrue);
      expect(LocalStorageService.getTelemetryBuffer().length, equals(3));
    });

    test(
      'enforces ring buffer capacity capping at 1000 points with FIFO eviction',
      () async {
        final t0 = DateTime(2026, 9, 11, 10, 0, 0);

        // Pre-fill buffer to 1005 points
        for (var i = 0; i < 1005; i++) {
          await LocalStorageService.bufferTelemetryPoint(
            latitude: -6.200000 + (i * 0.001), // > 15m each time
            longitude: 106.816666,
            timestamp: t0.add(Duration(seconds: i * 35)),
          );
        }

        final buffer = LocalStorageService.getTelemetryBuffer();
        expect(buffer.length, equals(LocalStorageService.maxTelemetryPoints));
        expect(buffer.length, equals(1000));

        // Oldest points should have been evicted (indices 0..4 evicted, oldest point should be i=5)
        final oldestPoint = buffer.first;
        final expectedOldestLat = -6.200000 + (5 * 0.001);
        expect(
          ((oldestPoint['latitude'] as double) - expectedOldestLat).abs(),
          lessThan(0.00001),
        );
      },
    );

    test('clearTelemetryBuffer empties the buffer', () async {
      await LocalStorageService.bufferTelemetryPoint(
        latitude: -6.200000,
        longitude: 106.816666,
      );
      expect(LocalStorageService.getTelemetryBuffer().isNotEmpty, isTrue);

      await LocalStorageService.clearTelemetryBuffer();
      expect(LocalStorageService.getTelemetryBuffer().isEmpty, isTrue);
    });
  });

  group('Citizen Report Queue CRUD', () {
    test('addFailedReport, getFailedReports, and clearFailedReports', () async {
      expect(LocalStorageService.getFailedReports().isEmpty, isTrue);

      await LocalStorageService.addFailedReport({
        'local_id': 'rep-001',
        'incident_type': 'banjir',
        'address_detail': 'Kp. Melayu',
      });

      final reports = LocalStorageService.getFailedReports();
      expect(reports.length, equals(1));
      expect(reports.first['incident_type'], equals('banjir'));

      await LocalStorageService.clearFailedReports();
      expect(LocalStorageService.getFailedReports().isEmpty, isTrue);
    });

    test(
      'cacheMyReports, getCachedMyReports, and clearCachedMyReports',
      () async {
        expect(LocalStorageService.getCachedMyReports(), isNull);

        final myReports = [
          {'id': 'r-1', 'status': 'investigating'},
          {'id': 'r-2', 'status': 'resolved'},
        ];
        await LocalStorageService.cacheMyReports(myReports);

        final cached = LocalStorageService.getCachedMyReports();
        expect(cached, isNotNull);
        expect(cached!.length, equals(2));

        await LocalStorageService.clearCachedMyReports();
        expect(LocalStorageService.getCachedMyReports(), isNull);
      },
    );
  });

  group('Legacy SharedPreferences Migration', () {
    test(
      'migrates existing SharedPreferences data into Hive and cleans legacy keys',
      () async {
        // 1. Reset LocalStorageService
        await LocalStorageService.resetForTesting();

        // 2. Populate mock SharedPreferences with legacy keys
        SharedPreferences.setMockInitialValues({
          'pending_sos': jsonEncode({
            'local_id': 'legacy-sos-999',
            'latitude': -6.175392,
            'longitude': 106.827153,
            'address_detail': 'Monas Jakarta',
          }),
          'pending_cancel_sos': 'legacy-cancel-sos-888',
          'pending_incident_type': 'kebakaran',
          'sos_cooldown_end_time': DateTime.now()
              .add(const Duration(minutes: 3))
              .toIso8601String(),
          'cached_my_history': jsonEncode([
            {'id': 'hist-1', 'type': 'medis'},
          ]),
          'failed_reports': [
            jsonEncode({'local_id': 'fail-1', 'title': 'Laporan Banjir'}),
          ],
          'cached_my_reports': jsonEncode([
            {'id': 'rep-1', 'title': 'Pohon Tumbang'},
          ]),
        });

        // 3. Re-initialize LocalStorageService (triggers _migrateFromSharedPreferences)
        await LocalStorageService.init(storagePath: tempDir.path);

        // 4. Assert data successfully migrated into Hive
        final sos = LocalStorageService.getPendingSOS();
        expect(sos, isNotNull);
        expect(sos!['local_id'], equals('legacy-sos-999'));

        expect(
          LocalStorageService.getPendingCancelSOS(),
          equals('legacy-cancel-sos-888'),
        );
        expect(
          LocalStorageService.getPendingIncidentType(),
          equals('kebakaran'),
        );
        expect(LocalStorageService.getCooldownEndTime(), isNotNull);

        final cachedHist = LocalStorageService.getCachedIncidents(
          'cached_my_history',
        );
        expect(cachedHist, isNotNull);
        expect(cachedHist!.length, equals(1));
        expect(cachedHist.first['id'], equals('hist-1'));

        final failedReps = LocalStorageService.getFailedReports();
        expect(failedReps.length, equals(1));
        expect(failedReps.first['local_id'], equals('fail-1'));

        final cachedReps = LocalStorageService.getCachedMyReports();
        expect(cachedReps, isNotNull);
        expect(cachedReps!.length, equals(1));
        expect(cachedReps.first['id'], equals('rep-1'));

        // 5. Assert legacy keys are removed from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('pending_sos'), isNull);
        expect(prefs.getString('pending_cancel_sos'), isNull);
        expect(prefs.getString('pending_incident_type'), isNull);
        expect(prefs.getString('sos_cooldown_end_time'), isNull);
        expect(prefs.getString('cached_my_history'), isNull);
        expect(prefs.getStringList('failed_reports'), isNull);
        expect(prefs.getString('cached_my_reports'), isNull);
        expect(prefs.getBool(LocalStorageService.migrationFlag), isTrue);
      },
    );
  });
}
