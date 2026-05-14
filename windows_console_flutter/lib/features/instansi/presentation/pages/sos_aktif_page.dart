import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/services/ws_service.dart';
import '../../../../core/constants/api_constants.dart';

class SosAktifPage extends StatefulWidget {
  final String token;
  final WsService ws;
  final VoidCallback? onOpenMap;
  const SosAktifPage({
    super.key,
    required this.token,
    required this.ws,
    this.onOpenMap,
  });

  @override
  State<SosAktifPage> createState() => _SosAktifPageState();
}

class _SosAktifPageState extends State<SosAktifPage> {
  List<IncidentModel> _incidents = [];
  IncidentModel? _selected;
  bool _loading = true;
  StreamSubscription<WsMessage>? _wsSub;
  Timer?
  _refreshTimer; // refresh tiap 5 detik agar indikator online/offline akurat

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _duration = d));
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _position = p));
    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });
    _wsSub = widget.ws.eventStream.listen((msg) {
      if (!mounted) return;
      if (msg.event == WsEvent.incomingEmergency) {
        _load();
      } else if (msg.event == WsEvent.sosCancelled ||
          msg.event == WsEvent.rescueAccepted ||
          msg.event == WsEvent.sosStatusUpdate ||
          msg.event == WsEvent.connected) {
        _load();
      } else if (msg.event == WsEvent.locationUpdate) {
        final incId = msg.payload['incident_id']?.toString() ?? '';
        final lat = (msg.payload['latitude'] as num?)?.toDouble();
        final lng = (msg.payload['longitude'] as num?)?.toDouble();
        final updatedStr = msg.payload['updated_at'] as String?;
        if (incId.isNotEmpty && lat != null && lng != null) {
          setState(() {
            final idx = _incidents.indexWhere((i) => i.id == incId);
            if (idx >= 0) {
              _incidents[idx] = _incidents[idx].copyWith(
                latitude: lat,
                longitude: lng,
                updatedAt: updatedStr != null
                    ? DateTime.tryParse(updatedStr)
                    : null,
              );
              if (_selected?.id == incId) {
                _selected = _incidents[idx];
              }
            }
          });
        }
      }
    });
    // Refresh data setiap 15 detik agar update status (handled, resolved, dll) langsung terlihat
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await IncidentApiService.getActiveIncidents(widget.token);
    if (mounted) {
      setState(() {
        _incidents = data;
        // Sinkronkan _selected - jika sudah resolved/selesai, clear selection
        if (_selected != null) {
          final updated = data.where((i) => i.id == _selected!.id).firstOrNull;
          if (updated != null) {
            if (updated.audioPath != null &&
                _selected!.audioPath != updated.audioPath) {
              final url = updated.audioPath!.startsWith('/uploads')
                  ? ApiConstants.baseUrl.replaceAll('/api/v1', '') +
                        updated.audioPath!
                  : updated.audioPath!;
              _audioPlayer.setSourceUrl(url);
            }
            _selected = updated;
          } else {
            _selected = null;
          }
        }
        _loading = false;
      });
    }
  }

  Future<void> _markFalseAlarm() async {
    if (_selected == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: const Text(
          'Konfirmasi Alarm Palsu',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Pengguna akan mendapat 1 strike. Setelah 3 strike, akun SOS akan diblokir.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Tandai Alarm Palsu',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = await IncidentApiService.markFalseAlarm(
      widget.token,
      _selected!.id,
      '',
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
    _audioPlayer.dispose();
    _wsSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Maps incident type string to the same icon used in the mobile app
  IconData _incidentIcon(String type) {
    switch (type) {
      case 'fire':
        return Icons.local_fire_department;
      case 'accident':
        return Icons.car_crash;
      case 'disaster':
        return Icons.water_damage;
      case 'crime':
        return Icons.warning_rounded;
      case 'medical':
        return Icons.medical_services;
      default:
        return Icons.report_outlined;
    }
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
                  child: RepaintBoundary(
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
                                    setState(() => _selected = inc);
                                    if (inc.audioPath != null) {
                                      final url =
                                          inc.audioPath!.startsWith('/uploads')
                                          ? ApiConstants.baseUrl.replaceAll(
                                                  '/api/v1',
                                                  '',
                                                ) +
                                                inc.audioPath!
                                          : inc.audioPath!;
                                      _audioPlayer.setSourceUrl(url);
                                    } else {
                                      _audioPlayer.stop();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            _incidentIcon(inc.incidentType),
                                            color: Colors.red,
                                            size: 18,
                                          ),
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
                  child: Icon(
                    _incidentIcon(inc.incidentType),
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
              value: inc.addressDetail != null
                  ? '${inc.addressDetail}\n(${inc.latitude.toStringAsFixed(5)}, ${inc.longitude.toStringAsFixed(5)})'
                  : '${inc.latitude.toStringAsFixed(5)}, ${inc.longitude.toStringAsFixed(5)}',
              actionIcon: Icons.open_in_new,
              onAction: () async {
                if (widget.onOpenMap != null) {
                  widget.onOpenMap!();
                } else {
                  final uri = Uri.parse(
                    'https://maps.google.com/?q=${inc.latitude},${inc.longitude}',
                  );
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                }
              },
            ),

            // ── Telemetri Korban ─────────────────────────────────────────────
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            const Text(
              'TELEMETRI KORBAN',
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
              'PROFIL KORBAN',
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
              actionIcon: inc.isNikVerified ? Icons.verified : null,
              actionIconColor: Colors.green,
            ),
            if (inc.reporterPhone != null)
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'HP',
                value: inc.reporterPhone!,
                actionIcon: inc.isPhoneVerified
                    ? Icons.check_circle
                    : Icons.error_outline,
                actionIconColor: inc.isPhoneVerified
                    ? Colors.green
                    : Colors.red,
                onAction: () => _callBack(inc.reporterPhone),
              )
            else
              const _InfoRow(
                icon: Icons.phone_outlined,
                label: 'HP',
                value: '- Belum disetel',
              ),
            if (inc.dob != null)
              _InfoRow(
                icon: Icons.cake_outlined,
                label: 'Tgl Lahir',
                value: inc.dob!,
              ),
            if (inc.domicile != null && inc.domicile!.isNotEmpty)
              _InfoRow(
                icon: Icons.home_outlined,
                label: 'Domisili',
                value: inc.domicile!,
              ),
            if (inc.bio != null && inc.bio!.isNotEmpty)
              _InfoRow(icon: Icons.info_outline, label: 'Bio', value: inc.bio!),
            if (inc.emergencyContact != null &&
                inc.emergencyContact!.isNotEmpty)
              _InfoRow(
                icon: Icons.contact_phone_outlined,
                label: 'Kontak Darurat',
                value: inc.emergencyContact!.replaceAll(' | ', '\n'),
              ),
            _InfoRow(
              icon: Icons.bloodtype_outlined,
              label: 'Gol. Darah',
              value: inc.bloodType ?? '- Tidak diketahui',
            ),
            _InfoRow(
              icon: Icons.medication_outlined,
              label: 'Alergi',
              value: inc.allergies ?? '- Tidak ada catatan',
            ),

            if (inc.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              const Text(
                '📸 BUKTI FOTO',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: inc.photoPaths.map((url) {
                  final fullUrl = url.startsWith('/uploads')
                      ? ApiConstants.baseUrl.replaceAll('/api/v1', '') + url
                      : url;
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.black,
                          insetPadding: EdgeInsets.zero,
                          child: Stack(
                            children: [
                              InteractiveViewer(
                                child: Center(
                                  child: Image.network(
                                    fullUrl,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        fullUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, _) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.white10,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (inc.audioPath != null) ...[
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              const Text(
                '🎙️ BUKTI AUDIO',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.green,
                      ),
                      onPressed: () {
                        if (_isPlaying) {
                          _audioPlayer.pause();
                        } else {
                          _audioPlayer.resume();
                        }
                      },
                    ),
                    Expanded(
                      child: Slider(
                        value: _position.inMilliseconds.toDouble().clamp(
                          0.0,
                          _duration.inMilliseconds > 0
                              ? _duration.inMilliseconds.toDouble()
                              : 1.0,
                        ),
                        max: _duration.inMilliseconds > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1.0,
                        onChanged: _duration.inMilliseconds > 0
                            ? (v) {
                                _audioPlayer.seek(
                                  Duration(milliseconds: v.toInt()),
                                );
                              }
                            : null,
                      ),
                    ),
                    Text(
                      '${_position.inMinutes.toString().padLeft(2, '0')}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / ${_duration.inMinutes.toString().padLeft(2, '0')}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

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

            if (inc.agencyStatus == 'pending' &&
                inc.status != 'resolved' &&
                inc.status != 'false_alarm' &&
                inc.status != 'canceled')
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
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.handshake, size: 18),
                      label: const Text(
                        'TANGANI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: () async {
                        final ok = await IncidentApiService.agencyHandle(
                          widget.token,
                          inc.id,
                        );
                        if (ok && mounted) {
                          _showSnack('Status ditangani', Colors.blue);
                          _load();
                        }
                      },
                    ),
                  ),
                ],
              )
            else if (inc.agencyStatus == 'handling')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text(
                    'SELESAIKAN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () async {
                    final ok = await IncidentApiService.resolve(
                      widget.token,
                      inc.id,
                    );
                    if (ok && mounted) {
                      _showSnack('Insiden diselesaikan', Colors.green);
                      _load();
                    }
                  },
                ),
              )
            else if (inc.handledByAgencyId != null &&
                inc.handledByAgencyId!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.business, color: Colors.white54, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Sedang ditangani instansi',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

            if (inc.volunteerResponseStatus == 'on_scene' ||
                inc.volunteerResponseStatus == 'waiting_review') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions_run, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Sedang ditangani relawan',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
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
    this.actionIconColor,
    this.onAction,
  });
  final IconData icon;
  final String label;
  final String value;
  final IconData? actionIcon;
  final Color? actionIconColor;
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
              icon: Icon(
                actionIcon,
                size: 18,
                color: actionIconColor ?? Colors.white54,
              ),
              onPressed: onAction,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
            ),
        ],
      ),
    );
  }
}
