// Purpose: Offline-state persistence tests backing reliability criterion C2:
// a pending SOS and its cooldown timestamp must survive app-level service
// re-initialization (process restart), and the purge path must clear both.
// Data & Logic Flow: LocalStorageService is initialized on a temp Hive
// directory, state is written, the service is reset and re-initialized on the
// SAME directory (simulating a restart), and state is asserted again.
// Key Components: WeakNet local-storage cooldown tests.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siagakita/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('weaknet_hive_');
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init(storagePath: tempDir.path);
  });

  tearDown(() async {
    await LocalStorageService.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('weaknet offline persistence', () {
    test(
      'pending SOS and cooldown survive a service re-init (restart)',
      () async {
        await LocalStorageService.savePendingSOS(
          localId: 'wn-sos-1',
          lat: -6.2,
          lng: 106.816666,
          addressDetail: 'WeakNet Restart Test',
        );
        final cooldownEnd = DateTime.now().add(const Duration(minutes: 5));
        await LocalStorageService.saveCooldownEndTime(cooldownEnd);

        // Simulate a process restart: same storage directory, fresh service.
        await LocalStorageService.resetForTesting();
        await LocalStorageService.init(storagePath: tempDir.path);

        final pending = LocalStorageService.getPendingSOS();
        expect(
          pending,
          isNotNull,
          reason: 'pending SOS must survive a restart',
        );
        expect(pending!.containsValue('wn-sos-1'), isTrue);

        final restored = LocalStorageService.getCooldownEndTime();
        expect(
          restored,
          isNotNull,
          reason: 'cooldown timestamp must survive a restart',
        );
        expect(
          restored!.isAfter(DateTime.now().add(const Duration(minutes: 4))),
          isTrue,
        );
      },
    );

    test('purge clears pending SOS and cooldown completely', () async {
      await LocalStorageService.savePendingSOS(
        localId: 'wn-sos-2',
        lat: -6.2,
        lng: 106.816666,
      );
      await LocalStorageService.saveCooldownEndTime(
        DateTime.now().add(const Duration(minutes: 5)),
      );

      await LocalStorageService.clearPendingSOS();
      await LocalStorageService.clearCooldownEndTime();

      expect(LocalStorageService.getPendingSOS(), isNull);
      expect(LocalStorageService.getCooldownEndTime(), isNull);
    });
  });
}
