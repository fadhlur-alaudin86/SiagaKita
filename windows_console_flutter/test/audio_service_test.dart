import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita_console/core/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioService Unit Tests (Sub-Issue #34)', () {
    setUp(() {
      AudioService.resetForTest(isPlayingState: false);
    });

    tearDown(() {
      AudioService.resetForTest(isPlayingState: false);
    });

    test('Initial playing state is false', () {
      expect(AudioService.isPlaying, isFalse);
    });

    test('resetForTest updates internal playing state properly', () {
      AudioService.resetForTest(isPlayingState: true);
      expect(AudioService.isPlaying, isTrue);

      AudioService.resetForTest(isPlayingState: false);
      expect(AudioService.isPlaying, isFalse);
    });

    test(
      'stop() resets playing state to false when previously playing',
      () async {
        AudioService.resetForTest(isPlayingState: true);
        expect(AudioService.isPlaying, isTrue);

        await AudioService.stop();
        expect(AudioService.isPlaying, isFalse);
      },
    );

    test('stop() is idempotent and safe when already stopped', () async {
      expect(AudioService.isPlaying, isFalse);
      await AudioService.stop();
      expect(AudioService.isPlaying, isFalse);
    });

    test(
      'playAlarm handles headless test environment gracefully without crashing',
      () async {
        // In headless test environments without native audio channels,
        // playAlarm should catch the MissingPluginException / platform error gracefully.
        expect(AudioService.isPlaying, isFalse);
        await AudioService.playAlarm(volume: 0.8);
        // If native channel fails, it should safely catch and revert playing state to false
        expect(AudioService.isPlaying, isFalse);
      },
    );
  });
}
