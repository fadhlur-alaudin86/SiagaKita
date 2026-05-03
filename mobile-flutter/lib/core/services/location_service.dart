import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// LocationService mengelola izin dan pengambilan koordinat GPS.
class LocationService {
  // ─── Request Permission ────────────────────────────────────────────────────

  /// Meminta izin lokasi dari pengguna.
  /// Return true jika izin granted, false jika denied.
  static Future<bool> requestPermission() async {
    // Cek dulu apakah service GPS aktif di device
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false; // GPS dimatikan di pengaturan device
    }

    var permission = await Permission.locationWhenInUse.status;

    if (permission.isDenied) {
      permission = await Permission.locationWhenInUse.request();
    }

    if (permission.isPermanentlyDenied) {
      // Buka settings agar user bisa aktifkan manual
      await openAppSettings();
      return false;
    }

    return permission.isGranted;
  }

  /// Mengembalikan true jika izin lokasi sudah granted.
  static Future<bool> hasPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  // ─── Get Current Position ──────────────────────────────────────────────────

  /// Mengambil koordinat GPS saat ini.
  /// Melempar [LocationException] jika GPS tidak tersedia.
  static Future<({double latitude, double longitude})>
  getCurrentPosition() async {
    if (!await hasPermission()) {
      throw LocationException('Izin GPS belum diberikan');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } on LocationServiceDisabledException {
      throw LocationException(
        'Layanan GPS tidak aktif. Aktifkan GPS di pengaturan.',
      );
    } catch (e) {
      throw LocationException('Gagal mengambil lokasi: $e');
    }
  }

  /// Mengambil koordinat GPS dengan fallback ke (0,0) jika gagal.
  /// Digunakan untuk kasus non-critical seperti update periodik.
  static Future<({double latitude, double longitude})?>
  getCurrentPositionOrNull() async {
    try {
      return await getCurrentPosition();
    } catch (_) {
      return null;
    }
  }
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => message;
}
