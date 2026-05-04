import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// ConnectivityService memantau status koneksi jaringan secara real-time.
/// Expose [isOnline] sebagai ValueNotifier agar UI bisa bereaksi langsung.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService _instance = ConnectivityService._();
  static ConnectivityService get instance => _instance;

  /// ValueNotifier yang dapat didengarkan oleh widget mana pun.
  static final ValueNotifier<bool> isOnline = ValueNotifier(true);

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Mulai memantau koneksi. Dipanggil sekali saat app start.
  Future<void> init() async {
    // Cek status awal
    final results = await Connectivity().checkConnectivity();
    isOnline.value = _isConnected(results);

    // Langganan perubahan koneksi
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = _isConnected(results);
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet,
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
