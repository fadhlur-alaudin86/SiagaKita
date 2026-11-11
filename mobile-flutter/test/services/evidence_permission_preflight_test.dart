// Purpose: Unit tests for the evidence permission pre-flight decision (F3,
// once-per-SOS guard). Pure logic — no permission_handler, no platform
// channels, no widgets.
// Data & Logic Flow: evaluateEvidencePreflight(cameraAllowed,
// microphoneAllowed) -> EvidencePreflightResult(skipCamera, skipMicrophone,
// showInfoMessage).
// Key Components: EvidencePreflightResult, evaluateEvidencePreflight.

import 'package:flutter_test/flutter_test.dart';

import 'package:siagakita/features/masyarakat/home_screen.dart';

void main() {
  group('evaluateEvidencePreflight', () {
    test('grants both: nothing skipped, no info message', () {
      final result = evaluateEvidencePreflight(
        cameraAllowed: true,
        microphoneAllowed: true,
      );
      expect(result.skipCamera, isFalse);
      expect(result.skipMicrophone, isFalse);
      expect(result.showInfoMessage, isFalse);
    });

    test('camera denied: skip camera only, show one info message', () {
      final result = evaluateEvidencePreflight(
        cameraAllowed: false,
        microphoneAllowed: true,
      );
      expect(result.skipCamera, isTrue);
      expect(result.skipMicrophone, isFalse);
      expect(result.showInfoMessage, isTrue);
    });

    test('microphone denied: skip microphone only, show one info message', () {
      final result = evaluateEvidencePreflight(
        cameraAllowed: true,
        microphoneAllowed: false,
      );
      expect(result.skipCamera, isFalse);
      expect(result.skipMicrophone, isTrue);
      expect(result.showInfoMessage, isTrue);
    });

    test('both denied: skip both, show one info message', () {
      final result = evaluateEvidencePreflight(
        cameraAllowed: false,
        microphoneAllowed: false,
      );
      expect(result.skipCamera, isTrue);
      expect(result.skipMicrophone, isTrue);
      expect(result.showInfoMessage, isTrue);
    });
  });
}
