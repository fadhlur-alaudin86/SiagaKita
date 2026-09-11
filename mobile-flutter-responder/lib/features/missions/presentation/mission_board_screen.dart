import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/services/background_telemetry_service.dart';
import '../../../core/services/responder_ws_service.dart';
import '../../../core/services/session_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/models/mission_model.dart';
import '../services/mission_service.dart';
import 'mission_detail_screen.dart';

class MissionBoardScreen extends StatefulWidget {
  const MissionBoardScreen({super.key});

  @override
  State<MissionBoardScreen> createState() => _MissionBoardScreenState();
}

class _MissionBoardScreenState extends State<MissionBoardScreen> {
  String? _officerName;
  String? _badgeNumber;
  Position? _currentPosition;
  StreamSubscription? _wsSubscription;
  bool _sirenActive = false;
  int _selectedFilterIndex = 0; // 0: Misi Aktif, 1: Semua Insiden

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLocation();
    _connectWebSocket();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MissionService>().loadMissions();
    });
  }

  Future<void> _loadProfile() async {
    final name = await SessionService.getFullName();
    final badge = await SessionService.getBadgeNumber();
    if (mounted) {
      setState(() {
        _officerName = name;
        _badgeNumber = badge;
      });
    }
  }

  Future<void> _loadLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
      }
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    await _loadLocation();
    if (!mounted) return;
    await context.read<MissionService>().loadMissions();
  }

  void _connectWebSocket() {
    final ws = context.read<ResponderWsService>();
    ws.connect();
    _wsSubscription = ws.onEvent.listen((msg) {
      if (msg.event == ResponderWsEvent.incidentAssignmentOffer ||
          msg.event == ResponderWsEvent.agencyHandling ||
          msg.event == ResponderWsEvent.sosCancelled ||
          msg.event == ResponderWsEvent.sosResolved) {
        if (mounted) {
          context.read<MissionService>().loadMissions();
          _triggerAlertVibration();
        }
      }
    });
  }

  Future<void> _triggerAlertVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Konfirmasi Keluar'.tr(ctx),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun petugas?'.tr(ctx),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal'.tr(ctx)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergencyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Keluar'.tr(ctx)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await BackgroundTelemetryService.stop();
      await SessionService.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final missionSvc = context.watch<MissionService>();
    final ws = context.watch<ResponderWsService>();

    List<MissionModel> filteredMissions = missionSvc.missions;
    if (_selectedFilterIndex == 0) {
      // Misi Aktif: Dalam penanganan atau ditugaskan
      filteredMissions = missionSvc.missions
          .where((m) => m.agencyStatus == 'handling' || m.status == 'handled')
          .toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Papan Misi'.tr(context),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '${_officerName ?? "Petugas Lapangan".tr(context)} (${_badgeNumber ?? "UNIT"})',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Telemetry Indicator Pill
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.successGreen),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gps_fixed, color: AppColors.successGreen, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Aktif'.tr(context),
                    style: const TextStyle(
                      color: AppColors.successGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Siren sound toggle
          IconButton(
            icon: Icon(
              _sirenActive ? Icons.volume_up : Icons.volume_off,
              color: _sirenActive ? AppColors.warningAmber : AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _sirenActive = !_sirenActive;
              });
            },
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar if offline
          if (!ws.isConnected)
            Container(
              width: double.infinity,
              color: AppColors.emergencyRed,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Menghubungkan ke Markas Komando...'.tr(context),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          // Filter Tabs
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text('Misi Aktif'.tr(context))),
                    selected: _selectedFilterIndex == 0,
                    selectedColor: AppColors.operationalBlue,
                    labelStyle: TextStyle(
                      color: _selectedFilterIndex == 0 ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilterIndex = 0);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text('Semua Insiden'.tr(context))),
                    selected: _selectedFilterIndex == 1,
                    selectedColor: AppColors.operationalBlue,
                    labelStyle: TextStyle(
                      color: _selectedFilterIndex == 1 ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilterIndex = 1);
                    },
                  ),
                ),
              ],
            ),
          ),
          // Mission List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.operationalBlue,
              backgroundColor: AppColors.surface,
              onRefresh: _onRefresh,
              child: missionSvc.isLoading && missionSvc.missions.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.operationalBlue),
                    )
                  : filteredMissions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppColors.textMuted, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada misi darurat aktif saat ini.'.tr(context),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tarik untuk memuat ulang'.tr(context),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredMissions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final mission = filteredMissions[index];
                            final distance = mission.formattedDistance(
                              _currentPosition?.latitude,
                              _currentPosition?.longitude,
                            );
                            return _buildMissionCard(context, mission, distance);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(BuildContext context, MissionModel mission, String distance) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MissionDetailScreen(mission: mission),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mission.agencyStatus == 'handling'
                ? AppColors.operationalBlue
                : AppColors.border,
            width: mission.agencyStatus == 'handling' ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.emergencyRed),
                  ),
                  child: Text(
                    mission.incidentType.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.emergencyRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusColor(mission.status).withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    mission.agencyStatus?.toUpperCase() ?? mission.status.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.statusColor(mission.status),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mission.addressDetail ?? 'Lokasi Kejadian'.tr(context),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 4),
                Text(
                  mission.reporterName,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const Spacer(),
                const Icon(Icons.near_me, color: AppColors.warningAmber, size: 16),
                const SizedBox(width: 4),
                Text(
                  distance,
                  style: const TextStyle(
                    color: AppColors.warningAmber,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
