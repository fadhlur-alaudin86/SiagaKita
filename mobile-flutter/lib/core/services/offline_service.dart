// Purpose: Offline SOS coordination service bridging UI workflows to LocalStorageService Hive storage.
// Data & Logic Flow: Receives offline SOS trigger and cancellation commands from HomeScreen and delegates persistence directly to LocalStorageService's in-memory Hive box.
// Key Components: OfflineService.

import 'local_storage_service.dart';

class OfflineService {
  // ─── Pending SOS (Offline SOS) ─────────────────────────────────────────────

  static Future<void> savePendingSOS({
    required String localId,
    required double lat,
    required double lng,
    String? addressDetail,
  }) async {
    await LocalStorageService.savePendingSOS(
      localId: localId,
      lat: lat,
      lng: lng,
      addressDetail: addressDetail,
    );
  }

  static Future<Map<String, dynamic>?> getPendingSOS() async {
    return LocalStorageService.getPendingSOS();
  }

  static Future<void> clearPendingSOS() async {
    await LocalStorageService.clearPendingSOS();
  }

  // ─── Pending Cancel SOS ──────────────────────────────────────────────────

  static Future<void> savePendingCancelSOS(String incidentId) async {
    await LocalStorageService.savePendingCancelSOS(incidentId);
  }

  static Future<String?> getPendingCancelSOS() async {
    return LocalStorageService.getPendingCancelSOS();
  }

  static Future<void> clearPendingCancelSOS() async {
    await LocalStorageService.clearPendingCancelSOS();
  }

  // ─── Last Cancelled Incident ID ──────────────────────────────────────────

  static Future<void> saveLastCancelledIncidentId(String incidentId) async {
    await LocalStorageService.saveLastCancelledIncidentId(incidentId);
  }

  static String? getLastCancelledIncidentId() {
    return LocalStorageService.getLastCancelledIncidentId();
  }

  static Future<void> clearLastCancelledIncidentId() async {
    await LocalStorageService.clearLastCancelledIncidentId();
  }

  // ─── Pending Incident Type ───────────────────────────────────────────────

  static Future<void> savePendingIncidentType(String type) async {
    await LocalStorageService.savePendingIncidentType(type);
  }

  static Future<String?> getPendingIncidentType() async {
    return LocalStorageService.getPendingIncidentType();
  }

  static Future<void> clearPendingIncidentType() async {
    await LocalStorageService.clearPendingIncidentType();
  }

  // ─── Cooldown End Time ───────────────────────────────────────────────────

  static Future<void> saveCooldownEndTime(DateTime endTime) async {
    await LocalStorageService.saveCooldownEndTime(endTime);
  }

  static Future<DateTime?> getCooldownEndTime() async {
    return LocalStorageService.getCooldownEndTime();
  }

  static Future<void> clearCooldownEndTime() async {
    await LocalStorageService.clearCooldownEndTime();
  }

  // ─── Pending Evidence ────────────────────────────────────────────────────

  static Future<void> savePendingEvidence({
    required String frontPath,
    required String rearPath,
    required String audioPath,
  }) async {
    await LocalStorageService.savePendingEvidence(
      frontPath: frontPath,
      rearPath: rearPath,
      audioPath: audioPath,
    );
  }

  static Future<Map<String, dynamic>?> getPendingEvidence() async {
    return LocalStorageService.getPendingEvidence();
  }

  static Future<void> clearPendingEvidence() async {
    await LocalStorageService.clearPendingEvidence();
  }
}
