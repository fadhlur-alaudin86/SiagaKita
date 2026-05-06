import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

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
        // Fallback jika tidak ada context
        await openAppSettings();
      }
      return false;
    }

    return permission.isGranted;
  }

  static Future<void> _showPermissionExplanationDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Izin Lokasi Diperlukan', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'SiagaKita membutuhkan akses lokasi agar bantuan dapat segera diarahkan ke tempat Anda secara akurat saat keadaan darurat.\n\n'
            'Mohon aktifkan izin lokasi secara manual melalui pengaturan aplikasi.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
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
              child: const Text('Buka Pengaturan'),
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
  static Future<({double latitude, double longitude})> getCurrentPosition() async {
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
    } catch (e) {
      throw AppLocationPermissionException('Gagal mengambil lokasi: $e');
    }
  }

  /// Mengambil koordinat GPS dengan fallback ke null jika gagal.
  /// Digunakan untuk kasus non-critical seperti update periodik.
  static Future<({double latitude, double longitude})?> getCurrentPositionOrNull() async {
    try {
      return await getCurrentPosition();
    } catch (_) {
      return null;
    }
  }
}
