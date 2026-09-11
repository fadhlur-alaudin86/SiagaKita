// Purpose:
//   Provides modular permission checking, validation queries, and batch request
//   capabilities across Location, Microphone, Camera, and Notification services.
//
// Data & Logic Flow:
//   1. Interrogates OS permission states via permission_handler and LocationService.
//   2. Exposes granular boolean async getters for feature-level pre-flight guards.
//   3. Coordinates fallback request routines.
//
// Key Components:
//   - PermissionService: Centralized utility class for runtime device permissions.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'location_service.dart';

class PermissionService {
  /// Checks whether high-accuracy GPS/location permission is granted.
  static Future<bool> hasLocationPermission() async {
    return await LocationService.hasPermission();
  }

  /// Checks whether microphone permission is granted.
  static Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Checks whether notification permission is granted.
  static Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Checks whether camera permission is granted.
  static Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Checks whether all critical permissions for emergency response (Location) are granted.
  static Future<bool> hasCriticalPermissions() async {
    return await hasLocationPermission();
  }

  /// Batch request for all application permissions.
  /// Primarily used when unprimed batch setup is explicitly initiated by user action.
  static Future<void> requestAllPermissions(BuildContext context) async {
    // 1. Lokasi & Background Location
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

    // 4. Notifikasi
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      await Permission.notification.request();
    }
  }
}
