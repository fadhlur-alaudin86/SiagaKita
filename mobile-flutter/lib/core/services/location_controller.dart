import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// Mode tracking GPS.
/// Prioritas: active > passive > off
enum TrackingMode { off, passive, active }

/// Singleton controller yang menyediakan posisi GPS terkini secara bersama
/// untuk seluruh screen. Mendukung priority-based mode agar SOS (active)
/// selalu menang atas Map (passive), dan GPS mati jika tidak ada yang butuh.
class LocationController extends ChangeNotifier {
  LocationController._();
  static final LocationController instance = LocationController._();

  // ─── Priority Mode System ─────────────────────────────────────────────────
  // Setiap caller mendaftarkan mode yang dibutuhkan.
  // Mode efektif = mode tertinggi di antara semua caller.
  final Map<String, TrackingMode> _callerModes = {};

  TrackingMode get mode => _effectiveMode;
  TrackingMode _effectiveMode = TrackingMode.off;

  /// Daftarkan atau ubah mode yang dibutuhkan oleh [caller].
  /// [caller] adalah string unik yang mengidentifikasi screen/komponen.
  /// Mode efektif otomatis dihitung ulang → stream GPS diperbarui.
  void requestMode(String caller, TrackingMode mode) {
    if (mode == TrackingMode.off) {
      _callerModes.remove(caller);
    } else {
      _callerModes[caller] = mode;
    }
    _recalculate();
  }

  /// Lepaskan kepemilikan mode dari [caller].
  /// Jika tidak ada lagi caller, GPS dimatikan.
  void releaseMode(String caller) {
    _callerModes.remove(caller);
    _recalculate();
  }

  void _recalculate() {
    TrackingMode highest = TrackingMode.off;
    for (final m in _callerModes.values) {
      if (m.index > highest.index) highest = m;
    }
    if (highest == _effectiveMode) return;
    _effectiveMode = highest;
    _updateSubscription();
    notifyListeners();
  }

  // ─── Legacy API (untuk kompatibilitas sementara) ──────────────────────────

  /// Legacy: set mode langsung tanpa caller tracking.
  /// Gunakan requestMode/releaseMode untuk kode baru.
  void setMode(TrackingMode newMode) {
    requestMode('__legacy__', newMode);
  }

  int _listenerCount = 0;
  void start() {
    _listenerCount++;
    requestMode('__legacy_start__', TrackingMode.passive);
  }

  void stop() {
    _listenerCount = (_listenerCount - 1).clamp(0, 99);
    if (_listenerCount == 0) {
      releaseMode('__legacy_start__');
    }
  }

  // ─── GPS Stream ───────────────────────────────────────────────────────────

  ({double lat, double lng})? _currentPosition;
  ({double lat, double lng})? get currentPosition => _currentPosition;

  StreamSubscription<Position>? _subscription;
  DateTime? _lastPassiveUpdate;

  void _updateSubscription() {
    _subscription?.cancel();
    _subscription = null;

    if (_effectiveMode == TrackingMode.off) return;

    final isActive = _effectiveMode == TrackingMode.active;
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      // active: update setiap kali ada pergerakan (0m filter)
      // passive: update setiap 1 meter (lebih responsif dari sebelumnya 5m)
      distanceFilter: isActive ? 0 : 1,
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (pos) {
        if (_effectiveMode == TrackingMode.active) {
          // Real-time: update setiap kali ada perubahan posisi
          _currentPosition = (lat: pos.latitude, lng: pos.longitude);
          notifyListeners();
        } else if (_effectiveMode == TrackingMode.passive) {
          // Passive: throttle ke 10 detik agar tidak terlalu sering (hemat baterai)
          final now = DateTime.now();
          if (_lastPassiveUpdate == null ||
              now.difference(_lastPassiveUpdate!) > const Duration(seconds: 10)) {
            _currentPosition = (lat: pos.latitude, lng: pos.longitude);
            _lastPassiveUpdate = now;
            notifyListeners();
          }
        }
      },
      onError: (e) => debugPrint('[LocationController] Stream error: $e'),
    );
  }

  /// Ambil posisi terbaru secara paksa (satu kali, tanpa stream).
  Future<({double lat, double lng})?> fetchNow() async {
    final pos = await LocationService.getCurrentPositionOrNull();
    if (pos != null) {
      _currentPosition = (lat: pos.latitude, lng: pos.longitude);
      notifyListeners();
    }
    return _currentPosition;
  }
}
