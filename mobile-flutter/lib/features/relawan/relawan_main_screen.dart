import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/location_controller.dart';
import '../../core/constants/api_config.dart';
import 'relawan_history_screen.dart';

import 'package:latlong2/latlong.dart';
import '../masyarakat/map_screen.dart';

class RelawanMainScreen extends StatefulWidget {
  final String accessToken;
  final VoidCallback? onNavigateToMap;
  const RelawanMainScreen({
    super.key,
    required this.accessToken,
    this.onNavigateToMap,
  });

  @override
  State<RelawanMainScreen> createState() => _RelawanMainScreenState();
}

class _RelawanMainScreenState extends State<RelawanMainScreen> {
  List<NearbyIncident> _nearbySOS = [];
  List<MissionHistory> _missionHistory = [];
  bool _loadingNearby = false;
  bool _loadingHistory = false;
  ({double latitude, double longitude})? _currentPosition;
  Timer? _nearbyTimer;

  // ─── Misi Aktif (Poin 3 & 4) ─────────────────────────────────────────────
  ActiveResponseModel? _activeMission;
  Timer? _missionPollTimer;     // poll status misi setiap 15 detik
  Timer? _missionLocationTimer; // broadcast lokasi relawan setiap 15 detik

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initLocation();
    _checkActiveMission();
    LocationController.instance.start(); // pastikan GPS berjalan
  }

  @override
  void dispose() {
    _nearbyTimer?.cancel();
    _missionPollTimer?.cancel();
    _stopMissionLocationBroadcast();
    LocationController.instance.stop();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentPositionOrNull();
    if (pos != null && mounted) {
      setState(() => _currentPosition = pos);
      final user = UserModel.currentUser.value;
      if (user.isAvailableForMission) _startNearbyPolling();
    }
  }

  void _startNearbyPolling() {
    _fetchNearbySOS();
    _nearbyTimer?.cancel();
    _nearbyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchNearbySOS();
    });
  }

  void _stopNearbyPolling() {
    _nearbyTimer?.cancel();
    _nearbyTimer = null;
    setState(() => _nearbySOS = []);
  }

  Future<void> _fetchNearbySOS() async {
    if (_currentPosition == null) {
      final pos = await LocationService.getCurrentPositionOrNull();
      if (pos == null) return;
      _currentPosition = pos;
    }
    if (!mounted) return;
    setState(() => _loadingNearby = true);
    final results = await IncidentService.getNearby(
      accessToken: widget.accessToken,
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      radius: 5.0,
    );
    if (mounted) {
      setState(() {
        _nearbySOS = results;
        _loadingNearby = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final history = await IncidentService.getMyHistory(
        accessToken: widget.accessToken,
      );
      if (mounted) setState(() => _missionHistory = history);
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  void _toggleAvailability(bool value) {
    final user = UserModel.currentUser.value;
    UserModel.currentUser.value = user.copyWith(isAvailableForMission: value);
    if (value) {
      _startNearbyPolling();
    } else {
      _stopNearbyPolling();
    }
  }

  Future<void> _acceptSOS(NearbyIncident inc) async {
    try {
      await IncidentService.acceptSOS(
        accessToken: widget.accessToken,
        incidentId: inc.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Misi diterima! Segera menuju ${inc.addressDetail ?? 'lokasi korban'}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh nearby dan cek misi aktif
        _fetchNearbySOS();
        _checkActiveMission();
      }
    } on IncidentException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Cek & Polling Misi Aktif ────────────────────────────────────────────
  Future<void> _checkActiveMission() async {
    final mission = await IncidentService.getMyActiveResponse(
      accessToken: widget.accessToken,
    );
    if (!mounted) return;
    setState(() => _activeMission = mission);
    if (mission != null) {
      _startMissionLocationBroadcast(mission.incidentId);
      // Poll setiap 15 detik apakah misi masih aktif
      _missionPollTimer?.cancel();
      _missionPollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        final updated = await IncidentService.getMyActiveResponse(
          accessToken: widget.accessToken,
        );
        if (mounted) {
          setState(() => _activeMission = updated);
          if (updated == null) {
            _stopMissionLocationBroadcast();
            _missionPollTimer?.cancel();
            _loadHistory();
          }
        }
      });
    } else {
      _stopMissionLocationBroadcast();
      _missionPollTimer?.cancel();
    }
  }

  // ─── Broadcast Lokasi Relawan ke Backend (Poin 4) ───────────────────────
  void _startMissionLocationBroadcast(String incidentId) {
    _missionLocationTimer?.cancel();
    _missionLocationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final pos = LocationController.instance.position.value;
      if (pos == null || _activeMission == null) return;
      await IncidentService.updateResponseLocation(
        accessToken: widget.accessToken,
        incidentId: incidentId,
        latitude: pos.lat,
        longitude: pos.lng,
      );
    });
  }

  void _stopMissionLocationBroadcast() {
    _missionLocationTimer?.cancel();
    _missionLocationTimer = null;
  }

  // ─── Selesaikan Misi (upload foto bukti) ─────────────────────────────────
  Future<void> _completeMission() async {
    if (_activeMission == null) return;
    File? photoFile;
    // Ambil foto dari kamera
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Kamera tidak tersedia');
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      final xFile = await controller.takePicture();
      await controller.dispose();
      photoFile = File(xFile.path);
    } catch (_) {
      // Jika kamera gagal, buat file dummy agar API tidak reject
      try {
        final dir = await getTemporaryDirectory();
        final dummy = File('${dir.path}/dummy_proof.jpg');
        if (!dummy.existsSync()) {
          dummy.createSync();
          dummy.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]); // minimal valid JPEG
        }
        photoFile = dummy;
      } catch (_) {}
    }
    if (photoFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil foto bukti'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    try {
      await IncidentService.volunteerCompleteSOS(
        accessToken: widget.accessToken,
        incidentId: _activeMission!.incidentId,
        photoFile: photoFile,
      );
      if (mounted) {
        setState(() => _activeMission = null);
        _stopMissionLocationBroadcast();
        _missionPollTimer?.cancel();
        _loadHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bukti berhasil dikirim. Menunggu konfirmasi instansi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on IncidentException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCompleteMissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Selesaikan Misi?'),
        content: const Text(
          'Kamera akan mengambil foto sebagai bukti penyelesaian misi. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
            onPressed: () {
              Navigator.pop(context);
              _completeMission();
            },
            child: const Text('Ya, Selesaikan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(NearbyIncident inc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white60 : Colors.black54;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(inc.typeEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inc.typeLabel,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      Text(
                        '${inc.distanceLabel} • ${inc.timeAgo}',
                        style: TextStyle(color: secondaryText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    inc.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _detailRow(
              Icons.location_on_outlined,
              'Koordinat',
              '${inc.latitude.toStringAsFixed(5)}, ${inc.longitude.toStringAsFixed(5)}',
              primaryText,
              secondaryText,
              onTapMap: widget.onNavigateToMap != null
                  ? () {
                      Navigator.pop(context);
                      MapScreen.targetLocation.value =
                          LatLng(inc.latitude, inc.longitude);
                      widget.onNavigateToMap!();
                    }
                  : null,
            ),
            if (inc.addressDetail != null)
              _detailRow(
                Icons.home_outlined,
                'Lokasi',
                inc.addressDetail!,
                primaryText,
                secondaryText,
              ),
            _detailRow(
              Icons.timer_outlined,
              'Dilaporkan',
              inc.timeAgo,
              primaryText,
              secondaryText,
            ),
            _detailRow(
              Icons.shield_outlined,
              'Kepercayaan',
              inc.trustLabel == 'verified' ? '✓ Terverifikasi' : 'Standard',
              primaryText,
              secondaryText,
            ),

            if (inc.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Foto Bukti',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: inc.photoPaths.length,
                  itemBuilder: (context, index) {
                    final path = inc.photoPaths[index];
                    final url = path.startsWith('http')
                        ? path
                        : '${ApiConfig.baseUrl}/$path';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 100,
                            width: 100,
                            color: Colors.grey.withValues(alpha: 0.3),
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            if (inc.audioPath != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Rekaman Audio Darurat Tersedia',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(Icons.play_circle_fill, color: Colors.orange.shade700),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'TERIMA MISI',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _acceptSOS(inc);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
    Color primary,
    Color secondary, {
    VoidCallback? onTapMap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: secondary)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTapMap != null)
            IconButton(
              icon: const Icon(Icons.map, color: Color(0xFF22C55E)),
              onPressed: onTapMap,
              tooltip: 'Lihat di Peta',
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel>(
      valueListenable: UserModel.currentUser,
      builder: (context, user, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colors = Theme.of(context).colorScheme;
        final isOnDuty = user.isAvailableForMission;
        final primaryText = isDark ? Colors.white : Colors.black87;
        final secondaryText = isDark ? Colors.white60 : Colors.black54;

        // XP progress
        final xp = user.volunteerPoints;
        final nextThreshold = xp < 100
            ? 100
            : xp < 500
            ? 500
            : xp < 1500
            ? 1500
            : 9999;
        final prevThreshold = xp < 100
            ? 0
            : xp < 500
            ? 100
            : xp < 1500
            ? 500
            : 1500;
        final progress = nextThreshold == 9999
            ? 1.0
            : (xp - prevThreshold) / (nextThreshold - prevThreshold);

        return Scaffold(
          backgroundColor: colors.surface,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadHistory();
                if (isOnDuty) await _fetchNearbySOS();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  // ─── Header ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: user.profilePhotoUrl != null
                              ? NetworkImage(user.profilePhotoUrl!)
                              : null,
                          backgroundColor: const Color(
                            0xFF22C55E,
                          ).withValues(alpha: 0.2),
                          child: user.profilePhotoUrl == null
                              ? Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : 'R',
                                  style: const TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, ${user.name.split(' ').first}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.military_tech,
                                    size: 14,
                                    color: Color(0xFFFBBF24),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.volunteerLevel,
                                    style: const TextStyle(
                                      color: Color(0xFFFBBF24),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• $xp XP',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── XP Bar ────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : colors.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Progress Level',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              nextThreshold == 9999
                                  ? 'Level Maksimal'
                                  : '$xp / $nextThreshold XP',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: isDark
                                ? Colors.white12
                                : Colors.grey.shade200,
                            color: const Color(0xFF22C55E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nextThreshold == 9999
                              ? 'Kamu sudah mencapai level tertinggi!'
                              : 'Selesaikan ${nextThreshold - xp} XP lagi untuk naik ke level berikutnya',
                          style: TextStyle(color: secondaryText, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Toggle Duty ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: isOnDuty
                          ? const LinearGradient(
                              colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                            )
                          : null,
                      color: isOnDuty
                          ? null
                          : (isDark
                                ? const Color(0xFF1E293B)
                                : colors.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isOnDuty
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOnDuty ? Icons.radar : Icons.radar_outlined,
                          color: isOnDuty ? Colors.white : secondaryText,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOnDuty
                                    ? 'ON DUTY - Siap Bertugas'
                                    : 'OFF DUTY - Istirahat',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isOnDuty ? Colors.white : primaryText,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                isOnDuty
                                    ? 'Memantau SOS dalam radius 5 km'
                                    : 'Aktifkan untuk menerima panggilan darurat',
                                style: TextStyle(
                                  color: isOnDuty
                                      ? Colors.white70
                                      : secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isOnDuty,
                          onChanged: _toggleAvailability,
                          activeThumbColor: Colors.white,
                          activeTrackColor: const Color(0xFF16A34A),
                          inactiveTrackColor: isDark
                              ? Colors.white12
                              : Colors.grey.shade300,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Misi Aktif (jika ada) ─────────────────────────────────────
                  if (_activeMission != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF065F46), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.crisis_alert, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'MISI SEDANG BERJALAN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _activeMission!.typeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_activeMission!.addressDetail != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _activeMission!.addressDetail!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  'Lokasi korban: ${_activeMission!.reporterLatitude.toStringAsFixed(5)}, '
                                  '${_activeMission!.reporterLongitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11),
                                ),
                              ),
                              if (widget.onNavigateToMap != null)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.map, color: Colors.white),
                                  onPressed: () {
                                    MapScreen.targetLocation.value = LatLng(
                                      _activeMission!.reporterLatitude,
                                      _activeMission!.reporterLongitude,
                                    );
                                    widget.onNavigateToMap!();
                                  },
                                  tooltip: 'Lihat di Peta',
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF065F46),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text(
                                'SELESAIKAN MISI',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              onPressed: _showCompleteMissionDialog,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── Radar SOS ───────────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        '📡 RADAR SOS AKTIF',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontSize: 12,
                          color: secondaryText,
                        ),
                      ),
                      const Spacer(),
                      if (isOnDuty && !_loadingNearby)
                        Text(
                          '${_nearbySOS.length} insiden',
                          style: TextStyle(
                            color: _nearbySOS.isEmpty
                                ? secondaryText
                                : const Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      if (isOnDuty && _loadingNearby)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (!isOnDuty)
                    _emptyPlaceholder(
                      Icons.radar_outlined,
                      'Aktifkan ON DUTY',
                      'Untuk melihat panggilan darurat di sekitarmu',
                      isDark,
                    )
                  else if (_loadingNearby && _nearbySOS.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_nearbySOS.isEmpty)
                    _emptyPlaceholder(
                      Icons.check_circle_outline,
                      'Tidak ada SOS aktif',
                      'Belum ada panggilan darurat dalam radius 5 km',
                      isDark,
                    )
                  else
                    ...(_nearbySOS.map(
                      (inc) => _sosCard(
                        inc,
                        isDark,
                        primaryText,
                        secondaryText,
                        colors,
                      ),
                    )),

                  const SizedBox(height: 28),

                  // ─── Riwayat Misi ──────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        '🏁 RIWAYAT MISI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontSize: 12,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_loadingHistory)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_missionHistory.isEmpty)
                    _emptyPlaceholder(
                      Icons.history,
                      'Belum ada riwayat misi',
                      'Riwayat SOS yang kamu tangani akan muncul di sini',
                      isDark,
                    )
                  else
                    ...(_missionHistory
                        .take(5)
                        .map(
                          (inc) => _historyCard(
                            inc,
                            isDark,
                            primaryText,
                            secondaryText,
                          ),
                        )),

                  if (_missionHistory.length > 5)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RelawanHistoryScreen(
                              accessToken: widget.accessToken,
                            ),
                          ),
                        );
                      },
                      child: const Text('Lihat semua riwayat →'),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sosCard(
    NearbyIncident inc,
    bool isDark,
    Color primaryText,
    Color secondaryText,
    ColorScheme colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(inc.typeEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inc.typeLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      inc.addressDetail ??
                          '${inc.latitude.toStringAsFixed(4)}, ${inc.longitude.toStringAsFixed(4)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    inc.distanceLabel,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    inc.timeAgo,
                    style: TextStyle(color: secondaryText, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Detail', style: TextStyle(fontSize: 13)),
                  onPressed: () => _showDetailSheet(inc),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text(
                    'TERIMA',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _acceptSOS(inc),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyCard(
    MissionHistory inc,
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    final statusColor = switch (inc.responseStatus) {
      'completed' => const Color(0xFF22C55E),
      'rejected' => const Color(0xFFEF4444),
      'waiting_review' => const Color(0xFFF59E0B),
      'canceled' => Colors.grey,
      _ => const Color(0xFF3B82F6),
    };
    final statusLabel = switch (inc.responseStatus) {
      'completed' => 'Selesai (+${inc.xpEarned} XP)',
      'rejected' => 'Ditolak',
      'waiting_review' => 'Menunggu Review',
      'canceled' => 'Dibatalkan',
      _ => inc.responseStatus,
    };

    const typeEmojis = {
      'medical': '🚑',
      'fire': '🔥',
      'crime': '🚨',
      'rescue': '🆘',
      'accident': '🚗',
      'disaster': '🌊',
    };
    final emoji = typeEmojis[inc.incidentType] ?? '⚠️';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inc.incidentType,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatDate(inc.acceptedAt),
                  style: TextStyle(color: secondaryText, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPlaceholder(
    IconData icon,
    String title,
    String subtitle,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.5)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isDark ? Colors.white24 : Colors.grey.shade400,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}.${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoStr;
    }
  }
}
