import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/models/user_model.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/location_controller.dart';
import '../../core/services/mobile_ws_service.dart';
import '../../core/constants/api_config.dart';
import '../../core/localization/app_localization.dart';
import '../../core/widgets/custom_camera_view.dart';
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

  // ─── Misi Aktif ─────────────────────────────────────────────
  ActiveResponseModel? _activeMission;
  Timer? _missionPollTimer; // poll status misi setiap 15 detik

  // ─── WebSocket & Vibration ─────────────────────────────────────────────
  MobileWsService? _ws;
  StreamSubscription<MobileWsMessage>? _wsSub;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initLocation();
    _checkActiveMission();

    // WebSocket real-time
    _ws = MobileWsService(token: widget.accessToken);
    _ws!.connect();
    _wsSub = _ws!.eventStream.listen(_onWsEvent);

    LocationController.instance.addListener(_handleLocationChange);
  }

  void _onWsEvent(MobileWsMessage msg) {
    if (!mounted) return;
    switch (msg.event) {
      case MobileWsEvent.reporterLocationUpdate:
        // Update posisi korban jika sedang dalam misi
        final p = msg.payload;
        if (_activeMission != null &&
            p['sos_id'] == _activeMission!.incidentId) {
          // Note: UI update for victim position on map handled via shared state or passing data
          // For now, we can update _activeMission or a separate state if needed.
        }
        break;
      case MobileWsEvent.sosResolved:
      case MobileWsEvent.sosCancelled:
      case MobileWsEvent.sosFalseAlarm:
        _checkActiveMission(); // refresh to clear mission
        break;
      case MobileWsEvent.forceLogout:
        _handleForceLogout();
        break;
      case MobileWsEvent.agencyHandling:
      case MobileWsEvent.volunteerHandling:
      case MobileWsEvent.volunteerLocationUpdate:
      case MobileWsEvent.connected:
      case MobileWsEvent.unknown:
        break;
    }
  }

  void _handleForceLogout() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sesi Anda telah berakhir karena login di perangkat lain.'.tr(
            context,
          ),
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
    // Logout dan redirect ke login
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  void dispose() {
    _nearbyTimer?.cancel();
    _missionPollTimer?.cancel();
    _stopMissionLocationBroadcast();
    _wsSub?.cancel();
    _ws?.dispose();
    LocationController.instance.removeListener(_handleLocationChange);
    // Lepaskan GPS dari relawan caller
    LocationController.instance.releaseMode('relawan_mission');
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
              '${'Misi diterima! Segera menuju '.tr(context)}${inc.addressDetail ?? 'lokasi korban'.tr(context)}.',
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
    // Sync ke global state
    UserModel.currentUser.value = UserModel.currentUser.value.copyWith(
      hasActiveMission: mission != null,
    );
    if (mission != null) {
      _startMissionLocationBroadcast();
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
            UserModel.currentUser.value = UserModel.currentUser.value.copyWith(
              hasActiveMission: false,
            );
          }
        }
      });
    } else {
      _stopMissionLocationBroadcast();
      _missionPollTimer?.cancel();
    }
  }

  // ─── Broadcast Lokasi Relawan ke Backend (Real-time) ───────────────────
  void _startMissionLocationBroadcast() {
    // Daftarkan GPS mode active dengan caller ID khusus misi relawan
    LocationController.instance.requestMode(
      'relawan_mission',
      TrackingMode.active,
    );
  }

  void _stopMissionLocationBroadcast() {
    // Lepaskan GPS dari relawan caller
    LocationController.instance.releaseMode('relawan_mission');
    UserModel.currentUser.value = UserModel.currentUser.value.copyWith(
      hasActiveMission: false,
    );
  }

  DateTime? _lastLocationUpdate;

  Future<void> _handleLocationChange() async {
    final pos = LocationController.instance.currentPosition;
    if (pos == null || _activeMission == null || !mounted) return;

    // 1. Kirim lokasi terbaru via WebSocket (Real-time)
    _ws?.sendLocation(pos.lat, pos.lng);

    // 2. Fallback: Update di DB via HTTP (misal tiap 10 detik sekali saja)
    final now = DateTime.now();
    if (_lastLocationUpdate == null ||
        now.difference(_lastLocationUpdate!) > const Duration(seconds: 10)) {
      try {
        await IncidentService.updateResponseLocation(
          accessToken: widget.accessToken,
          incidentId: _activeMission!.incidentId,
          latitude: pos.lat,
          longitude: pos.lng,
        );
        if (mounted) {
          setState(() {
            _lastLocationUpdate = now;
            _currentPosition = (latitude: pos.lat, longitude: pos.lng);
          });
        }
      } catch (_) {}
    }
  }

  // ─── Selesaikan Misi (foto wajib oleh relawan) ───────────────────────────
  /// Buka kamera → relawan ambil foto bukti → upload ke API
  Future<void> _completeMission() async {
    if (_activeMission == null) return;

    if (!mounted) return;
    // Buka CustomCameraView — relawan harus foto sendiri (tidak bisa upload)
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomCameraView(
          title: 'Foto Bukti Penyelesaian'.tr(context),
          lensDirection: CameraLensDirection.back,
          showOverlay: false,
          allowFlip: true, // Boleh flip depan/belakang
          onPictureTaken: (XFile xFile) async {
            // Kompres foto
            File? photoFile;
            try {
              final dir = await getTemporaryDirectory();
              final outPath = p.join(
                dir.path,
                'mission_proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );
              final compressed = await FlutterImageCompress.compressAndGetFile(
                xFile.path,
                outPath,
                quality: 70,
                minWidth: 1280,
                minHeight: 960,
              );
              photoFile = compressed != null
                  ? File(compressed.path)
                  : File(xFile.path);
            } catch (_) {
              photoFile = File(xFile.path);
            }

            // Upload ke API
            try {
              await IncidentService.volunteerCompleteSOS(
                accessToken: widget.accessToken,
                incidentId: _activeMission!.incidentId,
                photoFile: photoFile,
              );
              if (mounted) {
                // Jangan langsung null-kan _activeMission,
                // biarkan poll berikutnya mengambil status waiting_review
                _checkActiveMission();
                // Refresh nearby agar SOS yang sudah diselesaikan hilang
                _fetchNearbySOS();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Bukti berhasil dikirim. Menunggu konfirmasi...'.tr(
                        context,
                      ),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } on IncidentException catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _showCompleteMissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Selesaikan Misi?'.tr(context)),
        content: Text(
          'Ambil foto bukti penyelesaian misi menggunakan kamera. Foto wajib diambil langsung (tidak bisa dari galeri).'
              .tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'.tr(context)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
            ),
            onPressed: () {
              Navigator.pop(context);
              _completeMission();
            },
            child: Text(
              'Buka Kamera'.tr(context),
              style: const TextStyle(color: Colors.white),
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
              'Koordinat'.tr(context),
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
                'Lokasi'.tr(context),
                inc.addressDetail!,
                primaryText,
                secondaryText,
              ),
            _detailRow(
              Icons.timer_outlined,
              'Dilaporkan'.tr(context),
              inc.timeAgo,
              primaryText,
              secondaryText,
            ),
            _detailRow(
              Icons.shield_outlined,
              'Kepercayaan'.tr(context),
              inc.trustLabel == 'verified'
                  ? '✓ Terverifikasi'.tr(context)
                  : 'Standard'.tr(context),
              primaryText,
              secondaryText,
            ),

            if (inc.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Foto Bukti'.tr(context),
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
                    Expanded(
                      child: Text(
                        'Rekaman Audio Darurat Tersedia'.tr(context),
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
                label: Text(
                  'TERIMA MISI'.tr(context),
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
              tooltip: 'Lihat di Peta'.tr(context),
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
                      isDisabled: user.isSOSActive,
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

                  // ─── Radar SOS (disembunyikan saat misi aktif) ───────────────────────
                  if (_activeMission == null) ...[
                    Row(
                      children: [
                        Text(
                          'RADAR SOS AKTIF'.tr(context),
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
                            '${_nearbySOS.length} ${'insiden'.tr(context)}',
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
                        'Aktifkan ON DUTY'.tr(context),
                        'Untuk melihat panggilan darurat di sekitarmu'.tr(
                          context,
                        ),
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
                        'Tidak ada SOS aktif'.tr(context),
                        'Belum ada panggilan darurat dalam radius 5 km'.tr(
                          context,
                        ),
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
                  ] else ...[
                    // Info: radar disembunyikan saat misi aktif
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF065F46).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radar,
                            color: Color(0xFF22C55E),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Radar SOS dinonaktifkan sementara selama misi berlangsung.'
                                  .tr(context),
                              style: const TextStyle(
                                color: Color(0xFF22C55E),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ─── Riwayat Misi ──────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'RIWAYAT MISI'.tr(context),
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
                      'Belum ada riwayat misi'.tr(context),
                      'Riwayat SOS yang kamu tangani akan muncul di sini'.tr(
                        context,
                      ),
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
                      child: Text('Lihat semua riwayat →'.tr(context)),
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
