// Purpose: Minimal client for the toxiproxy control API used by the weak-network test suites.
// Data & Logic Flow: Tests install deterministic toxics (latency, timeout) or
// disable proxies entirely through the REST control API, then drive the real
// service layer through the affected listeners. Default control URL targets the
// loopback-published port from docker-compose.test.yml.
// Key Components: ToxiproxyClient.

import 'dart:convert';

import 'package:http/http.dart' as http;

class ToxiproxyClient {
  ToxiproxyClient({String? controlUrl})
    : controlUrl = controlUrl ?? 'http://127.0.0.1:8474';

  final String controlUrl;

  // Created lazily: flutter_test's mock HTTP override only permits client
  // creation inside a test zone, so constructing one at load time crashes.
  http.Client? _lazyClient;
  http.Client get _http => _lazyClient ??= http.Client();

  static const String restProxy = 'rest_api';
  static const String wsProxy = 'ws_realtime';

  Map<String, String> get _headers => const {
    'Content-Type': 'application/json',
  };

  /// True when the toxiproxy control API answers.
  Future<bool> isUp() async {
    try {
      final res = await _http
          .get(Uri.parse('$controlUrl/version'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _postToxic(String proxy, Map<String, dynamic> body) async {
    final res = await _http.post(
      Uri.parse('$controlUrl/proxies/$proxy/toxics'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw StateError('toxic add failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Adds a fixed downstream latency in milliseconds.
  Future<void> addLatency(
    String proxy,
    int ms, {
    int jitter = 0,
    String? name,
  }) async {
    await _postToxic(proxy, {
      'name': name ?? 'latency_${ms}_${DateTime.now().microsecondsSinceEpoch}',
      'type': 'latency',
      'stream': 'downstream',
      'toxicity': 1.0,
      'attributes': {'latency': ms, 'jitter': jitter},
    });
  }

  /// Cuts any connection that stays open longer than [ms] milliseconds.
  Future<void> addTimeout(String proxy, int ms, {String? name}) async {
    await _postToxic(proxy, {
      'name': name ?? 'timeout_${ms}_${DateTime.now().microsecondsSinceEpoch}',
      'type': 'timeout',
      'stream': 'downstream',
      'toxicity': 1.0,
      'attributes': {'timeout': ms},
    });
  }

  Future<void> removeToxic(String proxy, String name) async {
    await _http.delete(Uri.parse('$controlUrl/proxies/$proxy/toxics/$name'));
  }

  /// Removes every toxic currently attached to [proxy].
  Future<void> clearToxics(String proxy) async {
    final res = await _http.get(Uri.parse('$controlUrl/proxies/$proxy'));
    if (res.statusCode != 200) return;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final toxics = (body['toxics'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final toxic in toxics) {
      await removeToxic(proxy, toxic['name'] as String);
    }
  }

  /// Disabling a proxy refuses new connections and kills existing ones;
  /// re-enabling restores normal forwarding. Used to simulate outages.
  Future<void> setProxyEnabled(String proxy, bool enabled) async {
    final res = await _http.post(
      Uri.parse('$controlUrl/proxies/$proxy'),
      headers: _headers,
      body: jsonEncode({'enabled': enabled}),
    );
    if (res.statusCode != 200) {
      throw StateError(
        'setProxyEnabled($enabled) failed: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// Restores the proxy to a clean, enabled state.
  Future<void> reset(String proxy) async {
    await clearToxics(proxy);
    await setProxyEnabled(proxy, true);
  }
}
