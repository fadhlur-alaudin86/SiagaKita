import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_config.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/session_service.dart';
import '../data/models/mission_model.dart';

class MissionService extends ChangeNotifier {
  List<MissionModel> _missions = [];
  List<MissionModel> get missions => List.unmodifiable(_missions);

  MissionModel? _activeMission;
  MissionModel? get activeMission => _activeMission;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadMissions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.get(ApiConfig.allActiveIncidents);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        _missions = data
            .map((item) => MissionModel.fromJson(item as Map<String, dynamic>))
            .where((m) => !m.isTerminal)
            .toList();

        // Sort: missions handled by this unit or most recent first
        _missions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Check active incident ID in local state
        final activeId = await SessionService.getActiveIncidentId();
        if (activeId != null) {
          _activeMission = _missions.cast<MissionModel?>().firstWhere(
            (m) => m?.id == activeId,
            orElse: () => null,
          );
        }
      } else {
        _errorMessage = 'Gagal memuat daftar misi';
      }
    } catch (e) {
      debugPrint('[MissionService] loadMissions error: $e');
      _errorMessage = 'Terjadi kesalahan saat memuat data';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMissionStatus({
    required String incidentId,
    required String status,
    String? proofPhotoUrl,
  }) async {
    try {
      final res = await ApiClient.post(
        ApiConfig.personnelStatus(incidentId),
        body: {'status': status, 'proof_photo_url': ?proofPhotoUrl},
      );

      if (res.statusCode == 200) {
        if (status == 'resolved') {
          // Mission completed: clear active incident in session
          await SessionService.setActiveIncidentId(null);
          _activeMission = null;
        } else {
          // Active mission in progress: mark active incident for high-freq telemetry
          await SessionService.setActiveIncidentId(incidentId);
        }
        await loadMissions();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[MissionService] updateMissionStatus error: $e');
      return false;
    }
  }
}
