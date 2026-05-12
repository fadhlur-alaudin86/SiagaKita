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
  static const String wsUrl = 'ws://$_host:$_wsPort/ws/connect';
}

// ─── Panduan ganti environment ────────────────────────────────────────────────
//
// Emulator Android (localhost host machine) : _host = '10.0.2.2'
// Local device (HP terhubung WiFi sama)     : _host = '192.168.x.x'
// Server produksi                           : _host = '139.59.99.230'
//
// ─────────────────────────────────────────────────────────────────────────────
