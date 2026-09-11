// Purpose: Embedded NoSQL local storage service backed by Hive for high-performance offline caching.
// Data & Logic Flow: Encapsulates Hive boxes for offline SOS queueing, cached incident feeds, volunteer GPS telemetry ring buffers, and offline report queues with sub-millisecond synchronous in-memory read access. Automatically migrates legacy data from SharedPreferences during cold boot.
// Key Components: LocalStorageService, Box names (sos_queue, incident_cache, telemetry_buffer, report_queue).

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String boxSosQueue = 'sos_queue';
  static const String boxIncidentCache = 'incident_cache';
  static const String boxTelemetryBuffer = 'telemetry_buffer';
  static const String boxReportQueue = 'report_queue';

  static const int maxTelemetryPoints = 1000;

  static Box<dynamic>? _sosQueueBox;
  static Box<dynamic>? _incidentCacheBox;
  static Box<dynamic>? _telemetryBox;
  static Box<dynamic>? _reportQueueBox;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Initialize Hive Flutter and open standard storage boxes.
  static Future<void> init({String? storagePath}) async {
    if (_initialized) return;

    if (storagePath != null) {
      Hive.init(storagePath);
    } else {
      await Hive.initFlutter();
    }

    _sosQueueBox = await Hive.openBox(boxSosQueue);
    _incidentCacheBox = await Hive.openBox(boxIncidentCache);
    _telemetryBox = await Hive.openBox(boxTelemetryBuffer);
    _reportQueueBox = await Hive.openBox(boxReportQueue);

    _initialized = true;

    await _migrateFromSharedPreferences();
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    if (_initialized) {
      await _sosQueueBox?.close();
      await _incidentCacheBox?.close();
      await _telemetryBox?.close();
      await _reportQueueBox?.close();
      _initialized = false;
    }
  }

  // ─── SOS Queue (Offline SOS) ────────────────────────────────────────────────

  static const String _keyPendingSos = 'pending_sos';
  static const String _keyPendingCancelSos = 'pending_cancel_sos';
  static const String _keyPendingIncidentType = 'pending_incident_type';
  static const String _keyCooldownEndTime = 'sos_cooldown_end_time';

  static Future<void> savePendingSOS({
    required String localId,
    required double lat,
    required double lng,
    String? addressDetail,
  }) async {
    final data = <String, dynamic>{
      'local_id': localId,
      'latitude': lat,
      'longitude': lng,
      'address_detail': addressDetail,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _sosQueueBox?.put(_keyPendingSos, data);
  }

  static Map<String, dynamic>? getPendingSOS() {
    final val = _sosQueueBox?.get(_keyPendingSos);
    if (val == null) return null;
    if (val is Map) {
      return Map<String, dynamic>.from(val);
    }
    if (val is String) {
      try {
        return jsonDecode(val) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> clearPendingSOS() async {
    await _sosQueueBox?.delete(_keyPendingSos);
  }

  static Future<void> savePendingCancelSOS(String incidentId) async {
    await _sosQueueBox?.put(_keyPendingCancelSos, incidentId);
  }

  static String? getPendingCancelSOS() {
    final val = _sosQueueBox?.get(_keyPendingCancelSos);
    return val as String?;
  }

  static Future<void> clearPendingCancelSOS() async {
    await _sosQueueBox?.delete(_keyPendingCancelSos);
  }

  static Future<void> savePendingIncidentType(String type) async {
    await _sosQueueBox?.put(_keyPendingIncidentType, type);
  }

  static String? getPendingIncidentType() {
    final val = _sosQueueBox?.get(_keyPendingIncidentType);
    return val as String?;
  }

  static Future<void> clearPendingIncidentType() async {
    await _sosQueueBox?.delete(_keyPendingIncidentType);
  }

  static Future<void> saveCooldownEndTime(DateTime endTime) async {
    await _sosQueueBox?.put(_keyCooldownEndTime, endTime.toIso8601String());
  }

  static DateTime? getCooldownEndTime() {
    final val = _sosQueueBox?.get(_keyCooldownEndTime);
    if (val != null && val is String) {
      return DateTime.tryParse(val);
    }
    return null;
  }

  static Future<void> clearCooldownEndTime() async {
    await _sosQueueBox?.delete(_keyCooldownEndTime);
  }

  // ─── Incident Cache ─────────────────────────────────────────────────────────

  static Future<void> cacheIncidents(
    String cacheKey,
    List<dynamic> data,
  ) async {
    final payload = <String, dynamic>{
      'data': data,
      'cached_at': DateTime.now().toIso8601String(),
    };
    await _incidentCacheBox?.put(cacheKey, payload);
  }

  static List<dynamic>? getCachedIncidents(
    String cacheKey, {
    Duration maxAge = const Duration(hours: 24),
  }) {
    final val = _incidentCacheBox?.get(cacheKey);
    if (val == null) return null;

    if (val is Map) {
      final cachedAtStr = val['cached_at'] as String?;
      if (cachedAtStr != null) {
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt != null && DateTime.now().difference(cachedAt) > maxAge) {
          return null;
        }
      }
      final data = val['data'];
      if (data is List) return data;
    }

    if (val is List) return val;

    return null;
  }

  static Future<void> clearIncidentCache(String cacheKey) async {
    await _incidentCacheBox?.delete(cacheKey);
  }

  // ─── Telemetry Ring Buffer (Offline GPS Breadcrumbs) ───────────────────────

  static const String _keyTelemetryList = 'points';

  /// Adds a telemetry coordinate point to the ring buffer.
  /// Applies distance and temporal decimation: skips recording if displacement < minDistanceMeters
  /// and elapsed time < minTimeDeltaSeconds.
  /// Enforces maximum capacity of maxTelemetryPoints (1,000) using FIFO eviction.
  static Future<bool> bufferTelemetryPoint({
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
    double? accuracy,
    DateTime? timestamp,
    double minDistanceMeters = 15.0,
    int minTimeDeltaSeconds = 30,
  }) async {
    final now = timestamp ?? DateTime.now();
    final rawList = _telemetryBox?.get(_keyTelemetryList);
    final List<Map<String, dynamic>> points = [];

    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          points.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // Distance and time decimation against the most recent point
    if (points.isNotEmpty) {
      final lastPoint = points.last;
      final lastLat = (lastPoint['latitude'] as num?)?.toDouble() ?? 0.0;
      final lastLng = (lastPoint['longitude'] as num?)?.toDouble() ?? 0.0;
      final lastTimeStr = lastPoint['timestamp'] as String?;
      final lastTime = lastTimeStr != null
          ? DateTime.tryParse(lastTimeStr)
          : null;

      final distMeters = _calculateHaversineMeters(
        lastLat,
        lastLng,
        latitude,
        longitude,
      );
      final secondsDiff = lastTime != null
          ? now.difference(lastTime).inSeconds.abs()
          : 999;

      if (distMeters < minDistanceMeters && secondsDiff < minTimeDeltaSeconds) {
        return false; // Point skipped by decimation
      }
    }

    // Enforce ring buffer size (drop oldest if at capacity)
    while (points.length >= maxTelemetryPoints) {
      points.removeAt(0);
    }

    points.add({
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'timestamp': now.toIso8601String(),
    });

    await _telemetryBox?.put(_keyTelemetryList, points);
    return true;
  }

  static List<Map<String, dynamic>> getTelemetryBuffer() {
    final rawList = _telemetryBox?.get(_keyTelemetryList);
    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  static Future<void> clearTelemetryBuffer() async {
    await _telemetryBox?.delete(_keyTelemetryList);
  }

  static double _calculateHaversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // ─── Citizen Report Queue ───────────────────────────────────────────────────

  static const String _keyFailedReports = 'failed_reports';
  static const String _keyCachedMyReports = 'cached_my_reports';

  static Future<void> addFailedReport(Map<String, dynamic> reportMap) async {
    final list = getFailedReports();
    list.add(reportMap);
    await _reportQueueBox?.put(_keyFailedReports, list);
  }

  static List<Map<String, dynamic>> getFailedReports() {
    final raw = _reportQueueBox?.get(_keyFailedReports);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  static Future<void> removeFailedReport(String id) async {
    final list = getFailedReports();
    list.removeWhere((item) => item['id'] == id);
    await _reportQueueBox?.put(_keyFailedReports, list);
  }

  static Future<void> clearFailedReports() async {
    await _reportQueueBox?.delete(_keyFailedReports);
  }

  static Future<void> cacheMyReports(List<dynamic> data) async {
    await _reportQueueBox?.put(_keyCachedMyReports, <String, dynamic>{
      'data': data,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  static List<dynamic>? getCachedMyReports() {
    final val = _reportQueueBox?.get(_keyCachedMyReports);
    if (val is Map && val['data'] is List) {
      return val['data'] as List<dynamic>;
    }
    return null;
  }

  static Future<void> clearCachedMyReports() async {
    await _reportQueueBox?.delete(_keyCachedMyReports);
  }

  // ─── Legacy SharedPreferences Migration ─────────────────────────────────────

  static const String migrationFlag = 'hive_migrated_v1';

  static Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(migrationFlag) == true) return;

      // 1. Pending SOS
      final legacyPendingSos = prefs.getString(_keyPendingSos);
      if (legacyPendingSos != null &&
          _sosQueueBox?.get(_keyPendingSos) == null) {
        try {
          final decoded = jsonDecode(legacyPendingSos) as Map<String, dynamic>;
          await _sosQueueBox?.put(_keyPendingSos, decoded);
          await prefs.remove(_keyPendingSos);
        } catch (_) {}
      }

      // 2. Pending Cancel SOS
      final legacyCancelSos = prefs.getString(_keyPendingCancelSos);
      if (legacyCancelSos != null &&
          _sosQueueBox?.get(_keyPendingCancelSos) == null) {
        await _sosQueueBox?.put(_keyPendingCancelSos, legacyCancelSos);
        await prefs.remove(_keyPendingCancelSos);
      }

      // 3. Pending Incident Type
      final legacyType = prefs.getString(_keyPendingIncidentType);
      if (legacyType != null &&
          _sosQueueBox?.get(_keyPendingIncidentType) == null) {
        await _sosQueueBox?.put(_keyPendingIncidentType, legacyType);
        await prefs.remove(_keyPendingIncidentType);
      }

      // 4. Cooldown End Time
      final legacyCooldown = prefs.getString(_keyCooldownEndTime);
      if (legacyCooldown != null &&
          _sosQueueBox?.get(_keyCooldownEndTime) == null) {
        await _sosQueueBox?.put(_keyCooldownEndTime, legacyCooldown);
        await prefs.remove(_keyCooldownEndTime);
      }

      // 5. Cached My History
      final legacyHistory = prefs.getString('cached_my_history');
      if (legacyHistory != null &&
          _incidentCacheBox?.get('cached_my_history') == null) {
        try {
          final decoded = jsonDecode(legacyHistory) as List<dynamic>;
          await cacheIncidents('cached_my_history', decoded);
          await prefs.remove('cached_my_history');
        } catch (_) {}
      }

      // 6. Cached Reporter History
      final legacyReporterHistory = prefs.getString('cached_reporter_history');
      if (legacyReporterHistory != null &&
          _incidentCacheBox?.get('cached_reporter_history') == null) {
        try {
          final decoded = jsonDecode(legacyReporterHistory) as List<dynamic>;
          await cacheIncidents('cached_reporter_history', decoded);
          await prefs.remove('cached_reporter_history');
        } catch (_) {}
      }

      // 7. Failed Reports
      final legacyFailedReports = prefs.getStringList(_keyFailedReports);
      if (legacyFailedReports != null &&
          _reportQueueBox?.get(_keyFailedReports) == null) {
        final list = <Map<String, dynamic>>[];
        for (final item in legacyFailedReports) {
          try {
            list.add(jsonDecode(item) as Map<String, dynamic>);
          } catch (_) {}
        }
        await _reportQueueBox?.put(_keyFailedReports, list);
        await prefs.remove(_keyFailedReports);
      }

      // 8. Cached My Reports
      final legacyMyReports = prefs.getString(_keyCachedMyReports);
      if (legacyMyReports != null &&
          _reportQueueBox?.get(_keyCachedMyReports) == null) {
        try {
          final decoded = jsonDecode(legacyMyReports) as List<dynamic>;
          await cacheMyReports(decoded);
          await prefs.remove(_keyCachedMyReports);
        } catch (_) {}
      }

      await prefs.setBool(migrationFlag, true);
    } catch (e) {
      debugPrint('[LocalStorageService] Legacy migration error: $e');
    }
  }
}
