// Purpose: Unit tests for OfflineService verifying offline SOS queue lifecycle, cancellation purge, and last cancelled incident ID tracking.
// Data & Logic Flow: Initializes temporary Hive storage, invokes OfflineService methods for SOS and cancellation workflows, and asserts state persistence and cleanup.
// Key Components: OfflineServiceTest.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siagakita/core/services/local_storage_service.dart';
import 'package:siagakita/core/services/offline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_service_test_');
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init(storagePath: tempDir.path);
  });

  tearDown(() async {
    await LocalStorageService.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('OfflineService SOS Queue Operations', () {
    test(
      'savePendingSOS, getPendingSOS, and clearPendingSOS delegates correctly',
      () async {
        expect(await OfflineService.getPendingSOS(), isNull);

        await OfflineService.savePendingSOS(
          localId: 'local-test-123',
          lat: -6.2088,
          lng: 106.8456,
          addressDetail: 'Jakarta Pusat',
        );

        final pending = await OfflineService.getPendingSOS();
        expect(pending, isNotNull);
        expect(pending!['local_id'], equals('local-test-123'));
        expect(pending['latitude'], equals(-6.2088));
        expect(pending['longitude'], equals(106.8456));
        expect(pending['address_detail'], equals('Jakarta Pusat'));

        await OfflineService.clearPendingSOS();
        expect(await OfflineService.getPendingSOS(), isNull);
      },
    );

    test(
      'savePendingCancelSOS, getPendingCancelSOS, and clearPendingCancelSOS',
      () async {
        expect(await OfflineService.getPendingCancelSOS(), isNull);

        await OfflineService.savePendingCancelSOS('incident-cancel-456');
        expect(
          await OfflineService.getPendingCancelSOS(),
          equals('incident-cancel-456'),
        );

        await OfflineService.clearPendingCancelSOS();
        expect(await OfflineService.getPendingCancelSOS(), isNull);
      },
    );

    test(
      'saveLastCancelledIncidentId, getLastCancelledIncidentId, and clearLastCancelledIncidentId',
      () async {
        expect(OfflineService.getLastCancelledIncidentId(), isNull);

        await OfflineService.saveLastCancelledIncidentId('incident-server-789');
        expect(
          OfflineService.getLastCancelledIncidentId(),
          equals('incident-server-789'),
        );

        await OfflineService.clearLastCancelledIncidentId();
        expect(OfflineService.getLastCancelledIncidentId(), isNull);
      },
    );

    test(
      'savePendingIncidentType, getPendingIncidentType, and clearPendingIncidentType',
      () async {
        expect(await OfflineService.getPendingIncidentType(), isNull);

        await OfflineService.savePendingIncidentType('medical');
        expect(
          await OfflineService.getPendingIncidentType(),
          equals('medical'),
        );

        await OfflineService.clearPendingIncidentType();
        expect(await OfflineService.getPendingIncidentType(), isNull);
      },
    );

    test(
      'saveCooldownEndTime, getCooldownEndTime, and clearCooldownEndTime',
      () async {
        expect(await OfflineService.getCooldownEndTime(), isNull);

        final endTime = DateTime.now().add(const Duration(minutes: 3));
        await OfflineService.saveCooldownEndTime(endTime);

        final retrieved = await OfflineService.getCooldownEndTime();
        expect(retrieved, isNotNull);
        expect(
          retrieved!.difference(endTime).inSeconds.abs(),
          lessThanOrEqualTo(1),
        );

        await OfflineService.clearCooldownEndTime();
        expect(await OfflineService.getCooldownEndTime(), isNull);
      },
    );

    test(
      'savePendingEvidence, getPendingEvidence, and clearPendingEvidence delegates correctly',
      () async {
        expect(await OfflineService.getPendingEvidence(), isNull);

        await OfflineService.savePendingEvidence(
          frontPath: '/tmp/test_front.jpg',
          rearPath: '/tmp/test_rear.jpg',
          audioPath: '/tmp/test_audio.m4a',
        );

        final pending = await OfflineService.getPendingEvidence();
        expect(pending, isNotNull);
        expect(pending!['front_path'], equals('/tmp/test_front.jpg'));
        expect(pending['rear_path'], equals('/tmp/test_rear.jpg'));
        expect(pending['audio_path'], equals('/tmp/test_audio.m4a'));

        await OfflineService.clearPendingEvidence();
        expect(await OfflineService.getPendingEvidence(), isNull);
      },
    );
  });

  group('OfflineService Cancellation Purge Scenario', () {
    test(
      'local-only cancellation completely purges queue and prevents ghost upload',
      () async {
        // Step 1: User initiates SOS while offline
        await OfflineService.savePendingSOS(
          localId: 'local-ghost-check-001',
          lat: -6.1754,
          lng: 106.8272,
          addressDetail: 'Monas, Jakarta',
        );
        await OfflineService.savePendingIncidentType('medical');

        // Verify queued
        expect(await OfflineService.getPendingSOS(), isNotNull);
        expect(
          await OfflineService.getPendingIncidentType(),
          equals('medical'),
        );

        // Step 2: User cancels offline before network connection is restored
        // The purge operation cleans all pending queues
        await OfflineService.clearPendingSOS();
        await OfflineService.clearPendingIncidentType();
        await OfflineService.clearPendingCancelSOS();

        // Step 3: Assert everything is purged - no ghost upload will occur on reconnect
        expect(await OfflineService.getPendingSOS(), isNull);
        expect(await OfflineService.getPendingIncidentType(), isNull);
        expect(await OfflineService.getPendingCancelSOS(), isNull);
      },
    );
  });
}
