// Purpose: Evidence spool purge tests backing audit finding F2 (P2 storage
// hygiene): no pending_evidence entry may outlive a missing pending_sos, and
// spooled files must be deleted with their entry.
// Data & Logic Flow: LocalStorageService is initialized on a temp Hive
// directory; a pending_evidence entry with real fake files is spooled, then
// purge/delete behavior is asserted. The startup sweep is exercised by
// resetting and re-initializing the service on the SAME directory (simulating
// a process restart).
// Key Components: LocalStorageService.purgeSpooledEvidence, init sweep.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siagakita/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String frontPath;
  late String rearPath;
  late String audioPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('weaknet_evidence_');
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init(storagePath: tempDir.path);

    frontPath = '${tempDir.path}/front.jpg';
    rearPath = '${tempDir.path}/rear.jpg';
    audioPath = '${tempDir.path}/audio.aac';
    await File(frontPath).writeAsBytes(const [0xFF, 0xD8, 0xFF]);
    await File(rearPath).writeAsBytes(const [0xFF, 0xD8, 0xFF]);
    await File(audioPath).writeAsBytes(const [0xFF, 0xFB]);
  });

  tearDown(() async {
    await LocalStorageService.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('purgeSpooledEvidence deletes spooled files and entry', () async {
    await LocalStorageService.savePendingEvidence(
      frontPath: frontPath,
      rearPath: rearPath,
      audioPath: audioPath,
    );

    expect(LocalStorageService.getPendingEvidence(), isNotNull);
    expect(File(frontPath).existsSync(), isTrue);

    await LocalStorageService.purgeSpooledEvidence();

    expect(File(frontPath).existsSync(), isFalse);
    expect(File(rearPath).existsSync(), isFalse);
    expect(File(audioPath).existsSync(), isFalse);
    expect(LocalStorageService.getPendingEvidence(), isNull);
  });

  test('purgeSpooledEvidence ignores missing files', () async {
    final missing = '${tempDir.path}/does-not-exist.jpg';
    await LocalStorageService.savePendingEvidence(
      frontPath: missing,
      rearPath: rearPath,
      audioPath: audioPath,
    );

    await LocalStorageService.purgeSpooledEvidence();

    expect(File(rearPath).existsSync(), isFalse);
    expect(File(audioPath).existsSync(), isFalse);
    expect(LocalStorageService.getPendingEvidence(), isNull);
  });

  test('purgeSpooledEvidence no-entry is no-op', () async {
    await LocalStorageService.purgeSpooledEvidence();
    expect(LocalStorageService.getPendingEvidence(), isNull);
  });

  test('sweep purges orphan when no pending SOS', () async {
    await LocalStorageService.savePendingEvidence(
      frontPath: frontPath,
      rearPath: rearPath,
      audioPath: audioPath,
    );
    // No pending_sos is saved: the entry is an orphan.

    // Simulate a process restart: same storage directory, fresh service.
    await LocalStorageService.resetForTesting();
    await LocalStorageService.init(storagePath: tempDir.path);

    expect(File(frontPath).existsSync(), isFalse);
    expect(File(rearPath).existsSync(), isFalse);
    expect(File(audioPath).existsSync(), isFalse);
    expect(LocalStorageService.getPendingEvidence(), isNull);
  });

  test('sweep keeps evidence when pending SOS exists', () async {
    await LocalStorageService.savePendingSOS(
      localId: 'wn-sos-3',
      lat: -6.2,
      lng: 106.816666,
    );
    await LocalStorageService.savePendingEvidence(
      frontPath: frontPath,
      rearPath: rearPath,
      audioPath: audioPath,
    );

    // Simulate a process restart: same storage directory, fresh service.
    await LocalStorageService.resetForTesting();
    await LocalStorageService.init(storagePath: tempDir.path);

    expect(LocalStorageService.getPendingSOS(), isNotNull);
    expect(LocalStorageService.getPendingEvidence(), isNotNull);
    expect(File(frontPath).existsSync(), isTrue);
  });
}
