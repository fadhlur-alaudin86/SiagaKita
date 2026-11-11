// Purpose: Weak-network service tests for the auth path: verifies that
// registration+OTP verification still works under added latency and degrades
// with an AuthException when the connection is cut or the proxy is fully down.
// Data & Logic Flow: Real users are bootstrapped via register + OTP (raw code
// fetched from Redis), driven through the toxiproxy rest_api listener while
// toxics are toggled at runtime. No TestWidgetsFlutterBinding here: once the
// binding is initialized inside a test zone, package:http requests are faked
// as 400s by flutter_test, which would defeat the purpose of these tests.
// Key Components: WeakNet auth tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita/core/services/auth_service.dart';

import '../helpers/toxiproxy_client.dart';
import '../helpers/weaknet_env.dart';

Future<void> main() async {
  final toxiproxy = ToxiproxyClient();

  group(
    'weaknet auth',
    () {
      late String email;
      const password = 'WeakNet#2026x';

      setUpAll(() async {
        final (_, capturedEmail) = await bootstrapTestUser();
        email = capturedEmail;
      });

      tearDown(() async {
        await toxiproxy.reset(ToxiproxyClient.restProxy);
      });

      test(
        'register + OTP verify succeeds through 400ms added latency',
        () async {
          await toxiproxy.addLatency(ToxiproxyClient.restProxy, 400);
          final watch = Stopwatch()..start();

          final (auth, _) = await bootstrapTestUser();

          watch.stop();
          expect(auth.accessToken, isNotEmpty);
          expect(
            watch.elapsedMilliseconds,
            greaterThanOrEqualTo(380),
            reason: 'flow must have detoured through the latency toxic',
          );
        },
      );

      test(
        'connection cut by timeout toxic surfaces as AuthException',
        () async {
          await toxiproxy.addTimeout(ToxiproxyClient.restProxy, 100);
          await expectLater(
            AuthService.login(email: email, password: password),
            throwsA(isA<AuthException>()),
          );
        },
      );

      test(
        'full proxy outage surfaces as AuthException and recovers',
        () async {
          await toxiproxy.setProxyEnabled(ToxiproxyClient.restProxy, false);
          await expectLater(
            AuthService.login(email: email, password: password),
            throwsA(isA<AuthException>()),
          );

          await toxiproxy.setProxyEnabled(ToxiproxyClient.restProxy, true);
          final (auth, _) = await bootstrapTestUser();
          expect(
            auth.accessToken,
            isNotEmpty,
            reason: 'full auth flow must recover after the outage ends',
          );
        },
      );
    },
    skip: hasWeaknetEnv
        ? null
        : 'requires live weaknet stack: run with --dart-define=API_BASE_URL/WS_BASE_URL',
  );
}
