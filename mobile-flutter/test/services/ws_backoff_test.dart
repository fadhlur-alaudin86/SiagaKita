// Purpose: Pure unit tests for the WebSocket reconnect backoff computation
// (F6). No Flutter bindings are exercised; the function under test is pure and
// deterministic given an injected Random source.
// Data & Logic Flow: computeReconnectDelay(attempt, base, cap, random) returns
// min(cap, base * 2^attempt), jittered by ±20% of the capped value. Tests
// assert exponential growth, the 60 s cap, and jitter bounds.
// Key Components: MobileWsService.computeReconnectDelay.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:siagakita/core/services/mobile_ws_service.dart';

void main() {
  group('computeReconnectDelay', () {
    test('grows exponentially with consecutive attempts', () {
      final random = Random(42);
      Duration? previous;
      for (var attempt = 0; attempt < 7; attempt++) {
        final delay = MobileWsService.computeReconnectDelay(
          attempt: attempt,
          random: random,
        );
        if (previous != null) {
          expect(
            delay.inMilliseconds,
            greaterThan(previous.inMilliseconds),
            reason:
                'attempt $attempt must back off beyond attempt '
                '${attempt - 1}',
          );
        }
        previous = delay;
      }
    });

    test('is capped at the 60 second ceiling regardless of attempt', () {
      final delay = MobileWsService.computeReconnectDelay(
        attempt: 50,
        random: Random(7),
      );
      // centre on the 60 s cap, jittered ±20 % → [48 s, 72 s].
      expect(delay.inSeconds, greaterThanOrEqualTo(48));
      expect(delay.inSeconds, lessThanOrEqualTo(72));
    });

    test('starts near the base delay for attempt 0', () {
      final delay = MobileWsService.computeReconnectDelay(
        attempt: 0,
        random: Random(1),
      );
      expect(delay.inSeconds, greaterThanOrEqualTo(0));
      expect(delay.inSeconds, lessThanOrEqualTo(2));
    });

    test('jitter stays within +/-20% of the capped value', () {
      // attempt 5 → base * 2^5 = 32 s (below the 60 s cap).
      final centerMs = (Duration(seconds: 32).inMilliseconds).toDouble();
      final lower = (centerMs * 0.8).round();
      final upper = (centerMs * 1.2).round();
      for (var seed = 0; seed < 50; seed++) {
        final delay = MobileWsService.computeReconnectDelay(
          attempt: 5,
          random: Random(seed),
        );
        expect(
          delay.inMilliseconds,
          greaterThanOrEqualTo(lower),
          reason: 'seed $seed below jitter floor',
        );
        expect(
          delay.inMilliseconds,
          lessThanOrEqualTo(upper),
          reason: 'seed $seed above jitter ceiling',
        );
      }
    });

    test('never returns a negative duration', () {
      for (var seed = 0; seed < 20; seed++) {
        final delay = MobileWsService.computeReconnectDelay(
          attempt: 30,
          random: Random(seed),
        );
        expect(delay, greaterThanOrEqualTo(Duration.zero));
      }
    });
  });
}
