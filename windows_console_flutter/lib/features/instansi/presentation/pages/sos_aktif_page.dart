import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/ws_service.dart';

class SosAktifPage extends StatefulWidget {
  final String token;
  final WsService ws;
  const SosAktifPage({super.key, required this.token, required this.ws});

  @override
  State<SosAktifPage> createState() => _SosAktifPageState();
}

class _SosAktifPageState extends State<SosAktifPage> {
  List<IncidentModel> _incidents = [];
  IncidentModel? _selected;
  bool _loading = true;
  StreamSubscription<WsMessage>? _wsSub;
  final _falseAlarmCtrl = TextEditingController();
  Timer? _refreshTimer; // refresh tiap 5 detik agar indikator online/offline akurat

  @override
  void initState() {
    super.initState();
    _load();
    _wsSub = widget.ws.eventStream.listen((msg) {
      if (!mounted) return;
      if (msg.event == WsEvent.incomingEmergency) {
        AudioService.playAlarm();
        _load();
      } else if (msg.event == WsEvent.sosCancelled ||
          msg.event == WsEvent.connected) {
        _load();
      }
    });
    // Refresh UI setiap 5 detik agar indikator online/offline akurat
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await IncidentApiService.getActiveIncidents(widget.token);
    if (mounted) {
      setState(() {
        _incidents = data;
        _loading = false;
      });
    }
  }

  Future<void> _markFalseAlarm() async {
    if (_selected == null) return;
    _falseAlarmCtrl.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: const Text(
          'Tandai False Alarm?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pengguna akan mendapat 1 strike. Setelah 3 strike, akun SOS akan diblokir.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _falseAlarmCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alasan (wajib)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tandai False Alarm'),
          ),
        ],
      ),
    );

    if (confirmed != true || _falseAlarmCtrl.text.isEmpty) return;
    final ok = await IncidentApiService.markFalseAlarm(
      widget.token,
      _selected!.id,
      _falseAlarmCtrl.text,
    );
    if (ok && mounted) {
      _showSnack(
        'Ditandai sebagai false alarm. Strike diberikan.',
        Colors.orange,
      );
      setState(() => _selected = null);
      _load();
    }
  }

  Future<void> _resolve() async {
    if (_selected == null) return;
    final ok = await IncidentApiService.resolve(widget.token, _selected!.id);
    if (ok && mounted) {
      AudioService.stop();
      _showSnack('Insiden diselesaikan ✅', Colors.green);
      setState(() => _selected = null);
      _load();
    }
  }

  void _callBack(String? phone) async {
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _showSnack(String msg, Color color) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  @override
  void dispose() {
    _wsSub?.cancel();
    _falseAlarmCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Kiri: Live List ────────────────────────────────────────────────
        SizedBox(
          width: 320,
          child: Card(
            color: const Color(0xFF1A2035),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'SOS Aktif',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (!_loading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _incidents.isEmpty
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${_incidents.length}',
                            style: TextStyle(
                              color: _incidents.isEmpty
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _incidents.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 36,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tidak ada SOS aktif',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _incidents.length,
                          separatorBuilder: (context, index) =>
                              const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, i) {
                            final inc = _incidents[i];
                            final isSelected = _selected?.id == inc.id;
                            return Material(
                              color: isSelected
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  AudioService.stop();
                                  setState(() => _selected = inc);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.red,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inc.typeLabel,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${inc.reporterName} • ${inc.timeAgo}',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Indikator Online/Offline korban
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: inc.isOnline
                                              ? Colors.greenAccent
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isSelected)
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 16),

        // ── Kanan: Detail Panel ────────────────────────────────────────────
        Expanded(
          child: _selected == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        color: Colors.white24,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pilih insiden dari daftar untuk melihat detail',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : _buildDetailPanel(_selected!),
        ),
      ],
    );
  }

  Widget _buildDetailPanel(IncidentModel inc) {
    final trustColor = switch (inc.trustLabel) {
      'verified' => Colors.green,
      'unverified' => Colors.red,
      _ => Colors.orange,
    };

    return Card(
      color: const Color(0xFF1A2035),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inc.typeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${inc.id.substring(0, 8)}...',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: trustColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: trustColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    inc.trustLabel.toUpperCase(),
                    style: TextStyle(
                      color: trustColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),

            // Info lokasi & waktu
            _InfoRow(
              icon: Icons.access_time,
              label: 'Waktu',
              value: inc.formattedTime,
            ),
            _InfoRow(icon: Icons.timelapse, label: 'Sejak', value: inc.timeAgo),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Koordinat',
              value:
                  '${inc.latitude.toStringAsFixed(5)}, ${inc.longitude.toStringAsFixed(5)}',
              actionIcon: Icons.open_in_new,
              onAction: () async {
                final uri = Uri.parse(
                  'https://maps.google.com/?q=${inc.latitude},${inc.longitude}',
                );
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            ),

            // ── Telemetri Korban ─────────────────────────────────────────────
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            const Text(
              '📡 TELEMETRI KORBAN',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Status online/offline
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: inc.isOnline
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: inc.isOnline
                          ? Colors.green.withValues(alpha: 0.4)
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: inc.isOnline
                              ? Colors.greenAccent
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        inc.isOnline ? 'Online' : 'Offline / Sinyal Hilang',
                        style: TextStyle(
                          color: inc.isOnline
                              ? Colors.greenAccent
                              : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.update_outlined,
              label: 'Terakhir',
              value: 'Lokasi diperbarui pukul ${inc.lastUpdateLabel}',
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            const Text(
              '👤 PROFIL KORBAN',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            _InfoRow(
              icon: Icons.person_outline,
              label: 'Nama',
              value: inc.reporterName,
            ),
            if (inc.reporterPhone != null)
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'HP',
                value: inc.reporterPhone!,
                actionIcon: Icons.phone,
                onAction: () => _callBack(inc.reporterPhone),
              )
            else
              const _InfoRow(
                icon: Icons.phone_outlined,
                label: 'HP',
                value: '— Belum diverifikasi',
              ),
            _InfoRow(
              icon: Icons.bloodtype_outlined,
              label: 'Gol. Darah',
              value: inc.bloodType ?? '— Tidak diketahui',
            ),
            _InfoRow(
              icon: Icons.medication_outlined,
              label: 'Alergi',
              value: inc.allergies ?? '— Tidak ada catatan',
            ),

            const SizedBox(height: 28),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            const Text(
              'AKSI',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.report_gmailerrorred_outlined,
                      size: 18,
                    ),
                    label: const Text('False Alarm'),
                    onPressed: _markFalseAlarm,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2EAF60),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'SELESAIKAN INSIDEN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: _resolve,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.actionIcon,
    this.onAction,
  });
  final IconData icon;
  final String label;
  final String value;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionIcon != null)
            IconButton(
              icon: Icon(actionIcon, color: Colors.blue, size: 16),
              onPressed: onAction,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
