import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import 'auth_service.dart';
import 'session_service.dart';

/// ApiClient membungkus komunikasi HTTP dengan interceptor otomatis:
/// 1. Injeksi header standar (Accept, Content-Type, Accept-Language, Authorization)
/// 2. Auto-Refresh token transparan saat menerima respons 401 Unauthorized
/// 3. Request queueing: mencegah multiple refresh calls bersamaan saat ada parallel requests
class ApiClient {
  static const Duration _defaultTimeout = Duration(seconds: 15);

  static bool _isRefreshing = false;
  static final List<Completer<String?>> _refreshQueue = [];

  /// Callback opsional yang dipanggil saat sesi benar-benar kedaluwarsa (refresh token expired)
  static VoidCallback? onSessionExpired;

  /// Helper eksekusi request dengan automatic 401 retry & token auto-rotation.
  static Future<http.Response> _executeWithRetry(
    Future<http.Response> Function(String? token) sendFn, {
    Duration? timeout,
    String? explicitToken,
  }) async {
    final activeToken = explicitToken ?? await SessionService.getToken();
    final response = await sendFn(
      activeToken,
    ).timeout(timeout ?? _defaultTimeout);

    if (response.statusCode != 401) {
      return response;
    }

    // Tangani 401 Unauthorized
    debugPrint(
      '[ApiClient] Received 401 Unauthorized. Attempting transparent token refresh...',
    );
    final newToken = await _acquireRefreshedToken();

    if (newToken == null) {
      // Refresh token kedaluwarsa atau invalid
      debugPrint(
        '[ApiClient] Refresh token failed or expired. Triggering session expiry.',
      );
      onSessionExpired?.call();
      return response;
    }

    // Retry request asli menggunakan token baru
    debugPrint(
      '[ApiClient] Retrying original request with new refreshed token...',
    );
    return await sendFn(newToken).timeout(timeout ?? _defaultTimeout);
  }

  /// Sinkronisasi antrean refresh token untuk mencegah race condition
  static Future<String?> _acquireRefreshedToken() async {
    if (_isRefreshing) {
      // Sedang ada refresh berjalan, masukkan ke antrean tunggu
      final completer = Completer<String?>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _isRefreshing = true;

    try {
      final currentRefreshToken = await SessionService.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        _resolveQueue(null);
        return null;
      }

      final result = await AuthService.refreshToken(currentRefreshToken);
      await SessionService.updateTokens(
        result.accessToken,
        result.refreshToken,
      );

      _resolveQueue(result.accessToken);
      return result.accessToken;
    } catch (e, stackTrace) {
      debugPrint('[ApiClient] Error refreshing token: $e\n$stackTrace');
      await SessionService.clearSession();
      _resolveQueue(null);
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  static void _resolveQueue(String? token) {
    while (_refreshQueue.isNotEmpty) {
      final completer = _refreshQueue.removeAt(0);
      if (!completer.isCompleted) {
        completer.complete(token);
      }
    }
  }

  // ─── HTTP Methods ─────────────────────────────────────────────────────────

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
    String? token,
  }) {
    return _executeWithRetry(
      (resolvedToken) => http.get(
        url,
        headers: {
          ...ApiConfig.headers(token: resolvedToken),
          ...?headers,
        },
      ),
      timeout: timeout,
      explicitToken: token,
    );
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
    String? token,
  }) {
    return _executeWithRetry(
      (resolvedToken) => http.post(
        url,
        headers: {
          ...ApiConfig.headers(token: resolvedToken),
          ...?headers,
        },
        body: body,
        encoding: encoding,
      ),
      timeout: timeout,
      explicitToken: token,
    );
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
    String? token,
  }) {
    return _executeWithRetry(
      (resolvedToken) => http.put(
        url,
        headers: {
          ...ApiConfig.headers(token: resolvedToken),
          ...?headers,
        },
        body: body,
        encoding: encoding,
      ),
      timeout: timeout,
      explicitToken: token,
    );
  }

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
    String? token,
  }) {
    return _executeWithRetry(
      (resolvedToken) => http.patch(
        url,
        headers: {
          ...ApiConfig.headers(token: resolvedToken),
          ...?headers,
        },
        body: body,
        encoding: encoding,
      ),
      timeout: timeout,
      explicitToken: token,
    );
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
    String? token,
  }) {
    return _executeWithRetry(
      (resolvedToken) => http.delete(
        url,
        headers: {
          ...ApiConfig.headers(token: resolvedToken),
          ...?headers,
        },
        body: body,
        encoding: encoding,
      ),
      timeout: timeout,
      explicitToken: token,
    );
  }
}
