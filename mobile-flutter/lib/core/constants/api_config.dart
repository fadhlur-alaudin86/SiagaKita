/// Konfigurasi API terpusat untuk mobile-flutter.
/// Ganti SERVER_HOST untuk pindah antara emulator, lokal, dan produksi.
class ApiConfig {
  // ──────────────────────────────────────────────────────────────────
  // GANTI DI SINI jika server berganti
  // ──────────────────────────────────────────────────────────────────
  static const String _host = String.fromEnvironment('API_HOST');
  static const String _httpPort = '8080';
  static const String _wsPort = '8081';

  // ──────────────────────────────────────────────────────────────────
  // Jangan ubah di bawah ini
  // ──────────────────────────────────────────────────────────────────
  static const String baseUrl = 'http://$_host:$_httpPort/api/v1';
  static const String wsUrl = 'ws://$_host:$_wsPort/v1/ws/connect';
}
