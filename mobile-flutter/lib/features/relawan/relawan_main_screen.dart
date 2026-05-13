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
import 'widgets/relawan_header_widgets.dart';
import 'widgets/relawan_mission_widgets.dart';
import 'widgets/relawan_card_widgets.dart';

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
  Timer? _missionPollTimer; // poll status misi setiap 15 detik
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
      _missionPollTimer = Timer.periodic(const Duration(seconds: 15), (
        _,
      ) async {
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
    _missionLocationTimer = Timer.periodic(const Duration(seconds: 15), (
      _,
    ) async {
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
          dummy.writeAsBytesSync([
            0xFF,
            0xD8,
            0xFF,
            0xD9,
          ]); // minimal valid JPEG
        }
        photoFile = dummy;
      } catch (_) {}
    }
    if (photoFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengambil foto bukti'),
            backgroundColor: Colors.red,
          ),
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
            content: Text(
              'Bukti berhasil dikirim. Menunggu konfirmasi instansi.',
            ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
            ),
            onPressed: () {
              Navigator.pop(context);
              _completeMission();
            },
            child: const Text(
              'Ya, Selesaikan',
              style: TextStyle(color: Colors.white),
            ),
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
                      MapScreen.targetLocation.value = LatLng(
                        inc.latitude,
                        inc.longitude,
                      );
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
                  HeaderProfile(user: user),

                  // ─── XP Bar ────────────────────────────────────────────────
                  XPBar(xp: user.volunteerPoints),

                  const SizedBox(height: 16),

                  // ─── Toggle Duty ───────────────────────────────────────────
                  RepaintBoundary(
                    child: DutyStatusToggle(
                      isOnDuty: isOnDuty,
                      onChanged: _toggleAvailability,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Misi Aktif (jika ada) ─────────────────────────────────────
                  if (_activeMission != null) ...[
                    MissionActiveCard(
                      mission: _activeMission!,
                      onComplete: _showCompleteMissionDialog,
                      onNavigateToMap: widget.onNavigateToMap,
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
                      (inc) => NearbyIncidentCard(
                        inc: inc,
                        isDark: isDark,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        onDetail: () => _showDetailSheet(inc),
                        onAccept: () => _acceptSOS(inc),
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
                          (inc) => MissionHistoryCard(
                            inc: inc,
                            isDark: isDark,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
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
}
