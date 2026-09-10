import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  @visibleForTesting
  static AudioPlayer player = AudioPlayer();
  static bool _playing = false;

  /// Mainkan sirine darurat. Loop terus hingga [stop] dipanggil.
  static Future<void> playAlarm({double volume = 1.0}) async {
    if (_playing) return;
    try {
      _playing = true;
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('audio/alarm.mp3'));
    } catch (e) {
      _playing = false;
      debugPrint('[Audio] Failed to play alarm: $e');
    }
  }

  /// Hentikan sirine.
  static Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await player.stop();
    } catch (e) {
      debugPrint('[Audio] Failed to stop alarm: $e');
    }
  }

  static bool get isPlaying => _playing;

  @visibleForTesting
  static void resetForTest({bool isPlayingState = false}) {
    _playing = isPlayingState;
  }
}
