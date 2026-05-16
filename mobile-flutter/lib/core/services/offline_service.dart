import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineService {
  static const String _pendingSosKey = 'pending_sos';
  static const String _pendingCancelSosKey = 'pending_cancel_sos';

  // ─── Pending SOS (Offline SOS) ─────────────────────────────────────────────

  static Future<void> savePendingSOS({
    required String localId,
    required double lat,
    required double lng,
    String? addressDetail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'local_id': localId,
      'latitude': lat,
      'longitude': lng,
      'address_detail': addressDetail,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_pendingSosKey, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getPendingSOS() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_pendingSosKey);
    if (str != null) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> clearPendingSOS() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSosKey);
  }

  // ─── Pending Cancel SOS ──────────────────────────────────────────────────

  static Future<void> savePendingCancelSOS(String incidentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCancelSosKey, incidentId);
  }

  static Future<String?> getPendingCancelSOS() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingCancelSosKey);
  }

  static Future<void> clearPendingCancelSOS() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCancelSosKey);
  }

  // ─── Pending Incident Type (simpan tipe insiden saat offline) ────────────

  static const String _pendingTypeKey = 'pending_incident_type';

  /// Simpan tipe insiden yang dipilih user saat offline,
  /// sehingga bisa di-sync ke server setelah upload berhasil.
  static Future<void> savePendingIncidentType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingTypeKey, type);
  }

  static Future<String?> getPendingIncidentType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingTypeKey);
  }

  static Future<void> clearPendingIncidentType() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingTypeKey);
  }
}
