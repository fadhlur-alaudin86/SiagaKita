import '../localization/app_localization.dart';

/// Konfigurasi API terpusat untuk mobile-flutter.
/// Mendukung multi-environment via --dart-define-from-file (.env.dev atau .env.prod)
/// serta fallback backward-compatible ke API_HOST.
class ApiConfig {
  static const String _rawBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _rawWsUrl = String.fromEnvironment('WS_BASE_URL');
  static const String _rawHost = String.fromEnvironment('API_HOST');

  // Fallback host jika API_HOST maupun API_BASE_URL tidak disediakan
  static const String _fallbackHost = _rawHost == '' ? '10.0.2.2' : _rawHost;
  static const String _httpPort = '8080';
  static const String _wsPort = '8081';

  // Base URL REST API:
  // 1. Menggunakan API_BASE_URL jika tersedia (contoh: https://api.siagakita.com/api/v1)
  // 2. Fallback ke http://$_fallbackHost:$_httpPort/api/v1
  static const String baseUrl = _rawBaseUrl != ''
      ? _rawBaseUrl
      : 'http://$_fallbackHost:$_httpPort/api/v1';

  // Base URL WebSocket:
  // 1. Menggunakan WS_BASE_URL jika tersedia (contoh: wss://api.siagakita.com/v1/ws/connect)
  // 2. Fallback ke ws://$_fallbackHost:$_wsPort/v1/ws/connect
  static const String wsUrl = _rawWsUrl != ''
      ? _rawWsUrl
      : 'ws://$_fallbackHost:$_wsPort/v1/ws/connect';

  /// Standard HTTP headers including Accept-Language for i18n hook.
  static Map<String, String> headers({String? token}) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Accept-Language': AppLocalization.currentLocaleCode,
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
