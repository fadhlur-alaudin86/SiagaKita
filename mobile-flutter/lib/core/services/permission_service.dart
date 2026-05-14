import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'location_service.dart';

class PermissionService {
  /// Meminta semua izin yang dibutuhkan aplikasi di awal setelah login.
  static Future<void> requestAllPermissions(BuildContext context) async {
    // 1. Lokasi & Background Location (menggunakan LocationService yang sudah ada)
    await LocationService.requestPermission(context);

    // 2. Kamera
    final cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      await Permission.camera.request();
    }

    // 3. Mikrofon
    final micStatus = await Permission.microphone.status;
    if (micStatus.isDenied) {
      await Permission.microphone.request();
    }
  }
}
