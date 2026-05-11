import 'dart:async';
import 'package:flutter/foundation.dart';
import 'location_service.dart';

/// Singleton controller yang menyediakan posisi GPS terkini secara bersama
/// untuk seluruh screen (HomeScreen, MapScreen). Satu timer, satu panggilan GPS.
class LocationController {
  LocationController._();
  static final LocationController instance = LocationController._();

  /// Posisi GPS terkini. Null jika belum tersedia.
  final ValueNotifier<({double lat, double lng})?> position =
      ValueNotifier(null);

  Timer? _timer;
  int _listenerCount = 0;

  /// Mulai tracking lokasi. Panggil di initState() setiap screen yang butuh lokasi.
  /// Aman dipanggil berkali-kali — hanya satu timer yang berjalan.
  void start() {
    _listenerCount++;
    if (_timer != null) return; // sudah berjalan
    _tick(); // ambil posisi pertama langsung
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
  }

  /// Hentikan tracking. Panggil di dispose() setiap screen.
  /// Timer hanya benar-benar berhenti jika tidak ada screen yang masih pakai.
  void stop() {
    _listenerCount = (_listenerCount - 1).clamp(0, 99);
    if (_listenerCount == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _tick() async {
    final pos = await LocationService.getCurrentPositionOrNull();
    if (pos != null) {
      position.value = (lat: pos.latitude, lng: pos.longitude);
    }
  }

  /// Ambil posisi terbaru secara paksa (tanpa menunggu interval timer).
  Future<({double lat, double lng})?> fetchNow() async {
    await _tick();
    return position.value;
  }
}
