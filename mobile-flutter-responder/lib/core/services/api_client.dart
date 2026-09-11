import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import 'session_service.dart';

/// ApiClient handles HTTP transport with:
/// 1. Automatic token injection & Accept-Language header matching user preference.
/// 2. Transparent 401 auto-rotation with queue locking.
/// 3. Standard error envelope handling.
class ApiClient {
  ApiClient._();

  static const Duration _defaultTimeout = Duration(seconds: 15);
  static bool _isRefreshing = false;
  static final List<Completer<String?>> _refreshQueue = [];

  static VoidCallback? onSessionExpired;

  static Future<Map<String, String>> _buildHeaders({
    String? token,
    Map<String, String>? extraHeaders,
  }) async {
    final activeToken = token ?? await SessionService.getToken();
    final locale = await SessionService.getLocale();

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Accept-Language': locale,
    };

    if (activeToken != null && activeToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $activeToken';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  static Future<http.Response> _executeWithRetry(
    Future<http.Response> Function(String? token) sendFn, {
    Duration? timeout,
    String? explicitToken,
  }) async {
    final activeToken = explicitToken ?? await SessionService.getToken();
    final response = await sendFn(activeToken).timeout(timeout ?? _defaultTimeout);

    if (response.statusCode != 401) {
      return response;
    }

    debugPrint('[ApiClient] 401 Unauthorized detected. Attempting transparent token rotation...');
    final newToken = await _acquireRefreshedToken();

    if (newToken == null) {
      debugPrint('[ApiClient] Token rotation failed. Session expired.');
      onSessionExpired?.call();
      return response;
    }

    debugPrint('[ApiClient] Retrying original request with new token...');
    return await sendFn(newToken).timeout(timeout ?? _defaultTimeout);
  }

  static Future<String?> _acquireRefreshedToken() async {
    if (_isRefreshing) {
      final completer = Completer<String?>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await SessionService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _drainQueue(null);
        return null;
      }

      final res = await http.post(
        Uri.parse(ApiConfig.refreshToken),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (body['data'] as Map<String, dynamic>?) ?? {};
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;

        if (newAccess != null && newRefresh != null) {
          await SessionService.updateTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );
          _drainQueue(newAccess);
          return newAccess;
        }
      }

      _drainQueue(null);
      return null;
    } catch (e) {
      debugPrint('[ApiClient] Error during refresh token call: $e');
      _drainQueue(null);
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  static void _drainQueue(String? token) {
    for (final completer in _refreshQueue) {
      if (!completer.isCompleted) {
        completer.complete(token);
      }
    }
    _refreshQueue.clear();
  }

  // HTTP Method Verbs
  static Future<http.Response> get(String url, {Map<String, String>? headers, Duration? timeout}) {
    return _executeWithRetry((token) async {
      final reqHeaders = await _buildHeaders(token: token, extraHeaders: headers);
      return http.get(Uri.parse(url), headers: reqHeaders);
    }, timeout: timeout);
  }

  static Future<http.Response> post(
    String url, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    return _executeWithRetry((token) async {
      final reqHeaders = await _buildHeaders(token: token, extraHeaders: headers);
      final encodedBody = body is String ? body : (body != null ? jsonEncode(body) : null);
      return http.post(Uri.parse(url), headers: reqHeaders, body: encodedBody);
    }, timeout: timeout);
  }

  static Future<http.Response> put(
    String url, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    return _executeWithRetry((token) async {
      final reqHeaders = await _buildHeaders(token: token, extraHeaders: headers);
      final encodedBody = body is String ? body : (body != null ? jsonEncode(body) : null);
      return http.put(Uri.parse(url), headers: reqHeaders, body: encodedBody);
    }, timeout: timeout);
  }

  static Future<http.Response> patch(
    String url, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    return _executeWithRetry((token) async {
      final reqHeaders = await _buildHeaders(token: token, extraHeaders: headers);
      final encodedBody = body is String ? body : (body != null ? jsonEncode(body) : null);
      return http.patch(Uri.parse(url), headers: reqHeaders, body: encodedBody);
    }, timeout: timeout);
  }
}
