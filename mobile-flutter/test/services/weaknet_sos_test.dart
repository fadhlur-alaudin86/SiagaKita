// Purpose: Weak-network service tests for the critical one-tap SOS path:
// trigger must survive added latency and fail loudly (IncidentException) when
// the connection is cut, never hanging indefinitely.
// Data & Logic Flow: A real user is bootstrapped via register + OTP (Redis
// fetch), IncidentService.triggerSOS is driven through the toxiproxy rest_api
// listener with toxics toggled at runtime; triggered incidents are cancelled
// afterwards to keep the dev database clean.
// Key Components: WeakNet SOS tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita/core/services/incident_service.dart';

import '../helpers/toxiproxy_client.dart';
import '../helpers/weaknet_env.dart';

Future<void> main() async {
  final toxiproxy = ToxiproxyClient();

  group(
    'weaknet SOS',
    () {
      late String accessToken;
      final triggeredIncidentIds = <String>[];

      setUpAll(() async {
        final (auth, _) = await bootstrapTestUser();
        accessToken = auth.accessToken;
      });

      tearDown(() async {
        for (final id in triggeredIncidentIds) {
          try {
            await IncidentService.cancelSOS(
              accessToken: accessToken,
              incidentId: id,
            );
          } catch (_) {
            // Cancellation is best-effort cleanup; never mask test results.
          }
        }
        triggeredIncidentIds.clear();
        await toxiproxy.reset(ToxiproxyClient.restProxy);
      });

      test('triggerSOS succeeds through 300ms added latency', () async {
        await toxiproxy.addLatency(ToxiproxyClient.restProxy, 300);
        final result = await IncidentService.triggerSOS(
          accessToken: accessToken,
          latitude: -6.2,
          longitude: 106.816666,
          addressDetail: 'WeakNet Test Point',
        );

        expect(result.incidentId, isNotEmpty);
        triggeredIncidentIds.add(result.incidentId);
      });

      test(
        'triggerSOS under connection cut throws IncidentException, not hang',
        () async {
          await toxiproxy.addTimeout(ToxiproxyClient.restProxy, 100);
          await expectLater(
            IncidentService.triggerSOS(
              accessToken: accessToken,
              latitude: -6.2,
              longitude: 106.816666,
            ),
            throwsA(isA<IncidentException>()),
          );
        },
      );
    },
    skip: hasWeaknetEnv
        ? null
        : 'requires live weaknet stack: run with --dart-define=API_BASE_URL/WS_BASE_URL',
  );
}
