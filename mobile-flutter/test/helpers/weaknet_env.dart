// Purpose: Shared setup for weak-network service tests: endpoint resolution,
// stack-availability guard, OTP retrieval from Redis, and real test-user
// bootstrap through the register + verify-register-otp flow.
// Data & Logic Flow: --dart-define overrides (API_BASE_URL / WS_BASE_URL)
// default to the host toxiproxy listeners from docker-compose.test.yml. The
// backend stores raw OTP codes in Redis under otp:email:<purpose>:<email>, so
// tests fetch the code from Redis instead of a mailbox. Redis credentials are
// read from the gitignored infrastructure/.env.dev; nothing secret is tracked.
// Key Components: weaknetApiBase, weaknetWsBase, stackUp, bootstrapTestUser,
// waitFor.

import 'dart:async';
import 'dart:io';

import 'package:siagakita/core/services/auth_service.dart';

const String weaknetApiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:10000/api/v1',
);

const String weaknetWsBase = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'ws://127.0.0.1:10001/v1/ws/connect',
);

/// True when both weak-network base URLs are provided via --dart-define.
/// Computed at compile time: bare `flutter test` (defines absent) skips the
/// suites gracefully instead of failing in setUpAll.
const bool hasWeaknetEnv =
    String.fromEnvironment('API_BASE_URL') != '' &&
    String.fromEnvironment('WS_BASE_URL') != '';

const String _controlUrl = 'http://127.0.0.1:8474';

/// True when both the toxiproxy control API and the proxied backend answer.
/// Weak-network suites pass this as `skip:` so they degrade gracefully when
/// the local stack is not running.
Future<bool> stackUp() async {
  try {
    final version = await HttpClient()
        .getUrl(Uri.parse('$_controlUrl/version'))
        .then((req) => req.close())
        .timeout(const Duration(seconds: 3));
    if (version.statusCode != 200) return false;
    final docs = await HttpClient()
        .getUrl(Uri.parse('$weaknetApiBase/../docs/'))
        .then((req) => req.close())
        .timeout(const Duration(seconds: 5));
    return docs.statusCode != 0;
  } catch (_) {
    return false;
  }
}

String _readRedisPassword() {
  final candidates = [
    File('${Directory.current.path}/../infrastructure/.env.dev'),
    File('${Directory.current.path}/infrastructure/.env.dev'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        if (line.startsWith('REDIS_PASSWORD=')) {
          return line.substring('REDIS_PASSWORD='.length).trim();
        }
      }
    }
  }
  throw StateError(
    'REDIS_PASSWORD not found; looked in ${candidates.map((f) => f.path).join(', ')}',
  );
}

/// Reads a Redis key directly on the host (used to fetch OTP codes the backend
/// stored during register/login). Returns null when the key does not exist.
Future<String?> readRedisKey(String key) async {
  final result = await Process.run('redis-cli', [
    '-h',
    '127.0.0.1',
    '-p',
    '6379',
    '-a',
    _readRedisPassword(),
    '--no-auth-warning',
    'GET',
    key,
  ]).timeout(const Duration(seconds: 5));
  if (result.exitCode != 0) return null;
  final value = (result.stdout as String).trim();
  return value.isEmpty ? null : value;
}

/// Polls [probe] until it returns non-null or the timeout elapses.
Future<T> waitFor<T>(
  Future<T?> Function() probe, {
  required Duration timeout,
  String message = 'condition not met',
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final value = await probe();
    if (value != null) return value;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException(message, timeout);
}

/// Creates a real user through register + verify-register-otp and returns
/// `(authResult, email)` so callers can also exercise login flows. Each call
/// uses a fresh plus-addressed email so the shared per-email OTP cooldown
/// never interferes between tests.
Future<(AuthResult, String)> bootstrapTestUser() async {
  final email =
      'siagakita112+wn${DateTime.now().microsecondsSinceEpoch}@gmail.com';
  const password = 'WeakNet#2026x';

  await AuthService.register(
    fullName: 'WeakNet Tester',
    email: email,
    password: password,
  );

  final otp = await waitFor<String?>(
    () => readRedisKey('otp:email:register:$email'),
    timeout: const Duration(seconds: 10),
    message: 'register OTP for $email did not appear in Redis',
  );

  final auth = await AuthService.verifyRegisterOTP(email: email, otpCode: otp!);
  return (auth, email);
}
