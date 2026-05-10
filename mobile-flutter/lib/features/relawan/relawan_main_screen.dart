import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/location_service.dart';

class RelawanMainScreen extends StatefulWidget {
  final String accessToken;
  const RelawanMainScreen({super.key, required this.accessToken});

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

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initLocation();
  }

  @override
  void dispose() {
    _nearbyTimer?.cancel();
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
        _fetchNearbySOS();
      }
    } on IncidentException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
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
    Color secondary,
  ) {
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

                  // ─── Radar SOS ─────────────────────────────────────────────
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
                        // TODO: Navigate to full history page
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
