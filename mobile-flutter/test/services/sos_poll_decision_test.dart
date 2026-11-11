// Purpose: Unit tests for the status-poller null-active decision extracted
// from _startStatusPolling. Pure logic — no HTTP, no toxiproxy, no widgets.
// Data & Logic Flow: evaluateSosPollDecision(uploadStatus, pendingSos,
// userCancelled) -> SosPollDecision.resolve | retry.
// Key Components: SosPollDecision, evaluateSosPollDecision.

import 'package:flutter_test/flutter_test.dart';

import 'package:siagakita/features/masyarakat/home_screen.dart';

void main() {
  group('evaluateSosPollDecision', () {
    test('resolves when upload acknowledged (sent, no pending)', () {
      expect(
        evaluateSosPollDecision(
          uploadStatus: 'sent',
          pendingSos: null,
          userCancelled: false,
        ),
        equals(SosPollDecision.resolve),
      );
    });

    test('resolves when user cancelled regardless of upload status', () {
      expect(
        evaluateSosPollDecision(
          uploadStatus: 'sending',
          pendingSos: const {'local_id': 'abc'},
          userCancelled: true,
        ),
        equals(SosPollDecision.resolve),
      );
    });

    test('retries when a pending SOS record exists (undelivered)', () {
      expect(
        evaluateSosPollDecision(
          uploadStatus: 'sent',
          pendingSos: const {'local_id': 'abc'},
          userCancelled: false,
        ),
        equals(SosPollDecision.retry),
      );
    });

    test('retries when upload status is not sent and no pending', () {
      expect(
        evaluateSosPollDecision(
          uploadStatus: 'sending',
          pendingSos: null,
          userCancelled: false,
        ),
        equals(SosPollDecision.retry),
      );
    });

    test('retries when upload status is idle and no pending', () {
      expect(
        evaluateSosPollDecision(
          uploadStatus: 'idle',
          pendingSos: null,
          userCancelled: false,
        ),
        equals(SosPollDecision.retry),
      );
    });

    test('retries when upload status is retrying and pending exists', () {
      expect(
        evaluateSosPollDecision(
          uploadStatus: 'retrying',
          pendingSos: const {'local_id': 'abc'},
          userCancelled: false,
        ),
        equals(SosPollDecision.retry),
      );
    });
  });
}
