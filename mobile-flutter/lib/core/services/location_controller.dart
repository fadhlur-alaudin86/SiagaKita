import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// Singleton controller yang menyediakan posisi GPS terkini secara bersama
/// untuk seluruh screen (HomeScreen, MapScreen). Satu timer, satu panggilan GPS.
enum TrackingMode { off, passive, active }

/// Singleton controller yang menyediakan posisi GPS terkini.
/// Mendukung mode tracking yang berbeda untuk efisiensi baterai.
class LocationController extends ChangeNotifier {
  LocationController._();
  static final LocationController instance = LocationController._();

  TrackingMode _mode = TrackingMode.off;
  TrackingMode get mode => _mode;

  /// Posisi GPS terkini.
  ({double lat, double lng})? _currentPosition;
  ({double lat, double lng})? get currentPosition => _currentPosition;

  StreamSubscription<Position>? _subscription;
  DateTime? _lastPassiveUpdate;
  int _listenerCount = 0;

  /// Update mode tracking. Panggil di initState/dispose screen.
  void setMode(TrackingMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    _updateSubscription();
    notifyListeners();
  }

  /// Legacy start() - dipetakan ke passive mode untuk kompatibilitas sementara.
  void start() {
    _listenerCount++;
    setMode(TrackingMode.passive);
  }

  /// Legacy stop()
  void stop() {
    _listenerCount = (_listenerCount - 1).clamp(0, 99);
    if (_listenerCount == 0) {
      setMode(TrackingMode.off);
    }
  }

  void _updateSubscription() {
    _subscription?.cancel();
    _subscription = null;

    if (_mode == TrackingMode.off) return;

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _mode == TrackingMode.active ? 0 : 5,
    );

    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        if (_mode == TrackingMode.active) {
          // Real-time update
          _currentPosition = (lat: pos.latitude, lng: pos.longitude);
          notifyListeners();
        } else if (_mode == TrackingMode.passive) {
          // Throttle to ~10s
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

  /// Ambil posisi terbaru secara paksa.
  Future<({double lat, double lng})?> fetchNow() async {
    final pos = await LocationService.getCurrentPositionOrNull();
    if (pos != null) {
      _currentPosition = (lat: pos.latitude, lng: pos.longitude);
      notifyListeners();
    }
    return _currentPosition;
  }
}
