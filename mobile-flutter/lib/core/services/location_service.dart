import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../localization/app_localization.dart';

class AppLocationServiceDisabledException implements Exception {
  final String message;
  const AppLocationServiceDisabledException(this.message);
  @override
  String toString() => message;
}

class AppLocationPermissionException implements Exception {
  final String message;
  const AppLocationPermissionException(this.message);
  @override
  String toString() => message;
}

/// LocationService mengelola izin dan pengambilan koordinat GPS.
class LocationService {
  // ─── Request Permission ────────────────────────────────────────────────────

  /// Meminta izin lokasi dari pengguna.
  /// Return true jika izin granted, false jika denied.
  static Future<bool> requestPermission([BuildContext? context]) async {
    // Cek dulu apakah service GPS aktif di device
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false; // GPS dimatikan di pengaturan device
    }

    // 1. Notifikasi (untuk foreground service)
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      await Permission.notification.request();
    }

    // 2. Location When In Use (Wajib pertama di Android)
    var permission = await Permission.locationWhenInUse.status;

    if (permission.isDenied) {
      permission = await Permission.locationWhenInUse.request();
      if (permission.isDenied) {
        if (context != null && context.mounted) {
          await _showPermissionExplanationDialog(context);
        }
        return false;
      }
    }

    if (permission.isPermanentlyDenied) {
      if (context != null && context.mounted) {
        await _showPermissionExplanationDialog(context);
      } else {
        await openAppSettings();
      }
      return false;
    }

    // 3. Location Always (Untuk background)
    // Di Android 11+, ini akan membuka settings secara manual.
    final alwaysStatus = await Permission.locationAlways.status;
    if (alwaysStatus.isDenied && permission.isGranted) {
      await Permission.locationAlways.request();
    }

    // 4. Ignore Battery Optimizations
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (batteryStatus.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return permission.isGranted;
  }

  static Future<void> _showPermissionExplanationDialog(
    BuildContext context,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Izin Lokasi Diperlukan'.tr(context),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '${'SiagaKita membutuhkan akses lokasi agar bantuan dapat segera diarahkan ke tempat Anda secara akurat saat keadaan darurat.'.tr(context)}\n\n'
            '${'Mohon aktifkan izin lokasi secara manual melalui pengaturan aplikasi.'.tr(context)}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Batal'.tr(context),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: Text('Buka Pengaturan'.tr(context)),
            ),
          ],
        );
      },
    );
  }

  /// Mengembalikan true jika izin lokasi sudah granted.
  static Future<bool> hasPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  // ─── Get Current Position ──────────────────────────────────────────────────

  /// Mengambil koordinat GPS saat ini.
  /// Melempar exception spesifik jika gagal.
  static Future<({double latitude, double longitude})>
  getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const AppLocationServiceDisabledException(
        'Layanan GPS tidak aktif. Aktifkan GPS di pengaturan.',
      );
    }

    if (!await hasPermission()) {
      throw const AppLocationPermissionException('Izin GPS belum diberikan');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (e, stackTrace) {
      debugPrint('[LocationService] Error getting current position: $e\n$stackTrace');
      Error.throwWithStackTrace(
        AppLocationPermissionException('Gagal mengambil lokasi: $e'),
        stackTrace,
      );
    }
  }

  /// Mengambil koordinat GPS dengan fallback ke null jika gagal.
  /// Digunakan untuk kasus non-critical seperti update periodik.
  static Future<({double latitude, double longitude})?>
  getCurrentPositionOrNull() async {
    try {
      return await getCurrentPosition();
    } catch (e, stackTrace) {
      debugPrint('[LocationService] Optional position fetch failed: $e\n$stackTrace');
      return null;
    }
  }
}
