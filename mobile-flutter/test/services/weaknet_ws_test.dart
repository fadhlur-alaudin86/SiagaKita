// Purpose: Weak-network service tests for the realtime WebSocket client:
// connection through toxiproxy, forced outage via proxy disable, automatic
// reconnect after restore, and a clean disconnect that stops the reconnect
// loop.
// Data & Logic Flow: A real user token is obtained via register + OTP (Redis
// fetch); MobileWsService connects through the ws_realtime proxy listener and
// its 5-second reconnect timer is exercised against proxy state changes.
// Key Components: WeakNet WebSocket tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita/core/services/mobile_ws_service.dart';

import '../helpers/toxiproxy_client.dart';
import '../helpers/weaknet_env.dart';

Future<void> main() async {
  final toxiproxy = ToxiproxyClient();

  group(
    'weaknet WebSocket',
    () {
      late String accessToken;

      setUpAll(() async {
        final (auth, _) = await bootstrapTestUser();
        accessToken = auth.accessToken;
      });

      tearDown(() async {
        await toxiproxy.reset(ToxiproxyClient.wsProxy);
      });

      test('lifecycle: connect, outage drops it, auto-reconnect restores, '
          'clean disconnect stops the loop', () async {
        final service = MobileWsService(token: accessToken);

        // 1. Initial connect through the proxy.
        service.connect();
        await waitFor<bool?>(
          () async => service.isConnected ? true : null,
          timeout: const Duration(seconds: 15),
          message: 'WebSocket did not connect through toxiproxy',
        );

        // 2. Outage: disabling the proxy kills the established connection.
        await toxiproxy.setProxyEnabled(ToxiproxyClient.wsProxy, false);
        await waitFor<bool?>(
          () async => !service.isConnected ? true : null,
          timeout: const Duration(seconds: 10),
          message: 'connection survived a full proxy outage',
        );

        // 3. Restore: the 5-second reconnect timer must bring it back.
        await toxiproxy.setProxyEnabled(ToxiproxyClient.wsProxy, true);
        await waitFor<bool?>(
          () async => service.isConnected ? true : null,
          timeout: const Duration(seconds: 15),
          message: 'service did not reconnect after the outage ended',
        );

        // 4. Clean disconnect must stop the reconnect loop for good.
        service.disconnect();
        await Future<void>.delayed(const Duration(seconds: 6));
        expect(
          service.isConnected,
          isFalse,
          reason: 'reconnect loop must stay dead after disconnect()',
        );
        expect(service.isForceLoggedOut, isFalse);
      });
    },
    skip: hasWeaknetEnv
        ? null
        : 'requires live weaknet stack: run with --dart-define=API_BASE_URL/WS_BASE_URL',
  );
}
