import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/constants/api_constants.dart';

// ─── Page ─────────────────────────────────────────────────────────────────────

class LaporanMasukPage extends StatefulWidget {
  final String token;
  final void Function(double lat, double lng)? onOpenMap;
  final Set<String>? readIds;
  final void Function(String id)? onReportViewed;

  const LaporanMasukPage({
    super.key,
    required this.token,
    this.onOpenMap,
    this.readIds,
    this.onReportViewed,
  });

  @override
  State<LaporanMasukPage> createState() => _LaporanMasukPageState();
}

class _LaporanMasukPageState extends State<LaporanMasukPage> {
  List<ReportModel> _reports = [];
  ReportModel? _selected;
  bool _loading = true;
  String _filterStatus = 'all';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await IncidentApiService.getReports(
      widget.token,
      status: _filterStatus == 'all' ? null : _filterStatus,
    );
    if (mounted) {
      setState(() {
        _reports = data
            .where((r) => r.status == 'sent' || r.status == 'handled')
            .toList();
        // Keep selected in sync
        if (_selected != null) {
          final updated =
              _reports.where((r) => r.id == _selected!.id).firstOrNull;
          _selected = updated;
        }
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(
    String id,
    String status, [
    int? urgencyLevel,
  ]) async {
    await IncidentApiService.updateReportStatus(
      widget.token,
      id,
      status,
      urgencyLevel: urgencyLevel,
    );
    if (mounted) setState(() => _selected = null);
    _load();
  }

  IconData _incidentIcon(String type) {
    return switch (type) {
      'fire' => Icons.local_fire_department,
      'accident' => Icons.car_crash,
      'disaster' => Icons.water_damage,
      'crime' => Icons.warning_rounded,
      'medical' => Icons.medical_services,
      _ => Icons.report_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['sent', 'handled', 'all'];
    return Row(
      children: [
        // ── Kiri: Live List ──────────────────────────────────────────────────
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
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.inbox, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Laporan Aktif',
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
                            color: _reports.isEmpty
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${_reports.length}',
                            style: TextStyle(
                              color: _reports.isEmpty
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final f in filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              f == 'sent'
                                  ? 'MASUK'
                                  : f == 'handled'
                                  ? 'DITANGANI'
                                  : 'SEMUA',
                            ),
                            selected: _filterStatus == f,
                            onSelected: (_) {
                              setState(() {
                                _filterStatus = f;
                                _selected = null;
                              });
                              _load();
                            },
                            selectedColor: const Color(0xFFFF7418),
                            labelStyle: TextStyle(
                              color: _filterStatus == f
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: const Color(0xFF111827),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white54,
                          size: 16,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _load,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(color: Colors.white12, height: 1),

                // List
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _reports.isEmpty
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
                                'Tidak ada laporan',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _reports.length,
                          separatorBuilder: (context, index) =>
                              const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, i) {
                            final r = _reports[i];
                            final isSelected = _selected?.id == r.id;
                            return Material(
                              color: isSelected
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selected = r);
                                  // Tandai laporan ini sudah dilihat
                                  widget.onReportViewed?.call(r.id);
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
                                          color: Colors.orange.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          _incidentIcon(r.incidentType),
                                          color: Colors.orange,
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
                                              r.typeLabelId.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              r.reporterName,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Unread dot
                                      if (widget.readIds != null &&
                                          !widget.readIds!.contains(r.id))
                                        Container(
                                          width: 9,
                                          height: 9,
                                          margin: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: Colors.orange,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      // Status dot
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: r.status == 'sent'
                                              ? Colors.orange
                                              : Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isSelected)
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.orange,
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

        // ── Kanan: Detail Panel ──────────────────────────────────────────────
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
                        'Pilih laporan dari daftar untuk melihat detail',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : _ReportDetailPanel(
                  key: ValueKey(_selected!.id),
                  report: _selected!,
                  onUpdateStatus: (status, [urgency]) {
                    _updateStatus(_selected!.id, status, urgency);
                  },
                  onOpenMap: widget.onOpenMap,
                ),
        ),
      ],
    );
  }
}

// ─── Detail Panel ─────────────────────────────────────────────────────────────

class _ReportDetailPanel extends StatefulWidget {
  final ReportModel report;
  final void Function(String, [int?]) onUpdateStatus;
  final void Function(double lat, double lng)? onOpenMap;

  const _ReportDetailPanel({
    super.key,
    required this.report,
    required this.onUpdateStatus,
    this.onOpenMap,
  });

  @override
  State<_ReportDetailPanel> createState() => _ReportDetailPanelState();
}

class _ReportDetailPanelState extends State<_ReportDetailPanel> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int? _selectedUrgency;

  @override
  void initState() {
    super.initState();
    // Daftarkan semua listener terlepas dari ada tidaknya audio
    _audioPlayer.onDurationChanged.listen(
      (d) { if (mounted) setState(() => _duration = d); },
    );
    _audioPlayer.onPositionChanged.listen(
      (p) { if (mounted) setState(() => _position = p); },
    );
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

    // Set source audio dengan URL lengkap (path relatif harus di-build dulu)
    final rawAudio = widget.report.audioPath;
    if (rawAudio != null) {
      final audioUrl = rawAudio.startsWith('http')
          ? rawAudio
          : '${ApiConstants.baseUrl.replaceAll('/api/v1', '')}$rawAudio';
      _audioPlayer.setSourceUrl(audioUrl);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _fmtLocal(DateTime dt) {
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/'
        '${l.year}  '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  IconData _incidentIcon(String type) {
    return switch (type) {
      'fire' => Icons.local_fire_department,
      'accident' => Icons.car_crash,
      'disaster' => Icons.water_damage,
      'crime' => Icons.warning_rounded,
      'medical' => Icons.medical_services,
      _ => Icons.report_outlined,
    };
  }

  void _openImagePreview(String url) {
    final fullUrl = _buildPhotoUrl(url);
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
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (ctx, err, _) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildPhotoUrl(String url) {
    if (url.startsWith('http')) return url;
    final base = ApiConstants.baseUrl.replaceAll('/api/v1', '');
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Card(
      color: const Color(0xFF1A2035),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _incidentIcon(r.incidentType),
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.typeLabelId.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Laporan • ${r.statusLabelId.toUpperCase()}',
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
                    color: (r.status == 'sent' ? Colors.orange : Colors.blue)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: (r.status == 'sent' ? Colors.orange : Colors.blue)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    r.status == 'sent' ? 'MASUK' : 'DITANGANI',
                    style: TextStyle(
                      color:
                          r.status == 'sent' ? Colors.orange : Colors.blue,
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

            // ── Info ─────────────────────────────────────────────────────────
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Pelapor',
              value: r.reporterName,
            ),
            _InfoRow(
              icon: Icons.access_time,
              label: 'Waktu Masuk',
              value: _fmtLocal(r.createdAt),
            ),
            if (r.urgency != 'none')
              _InfoRow(
                icon: Icons.bar_chart,
                label: 'Urgensi',
                value: r.urgencyLabel,
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.white38),
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 90,
                    child: Text(
                      'Titik Lokasi',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.latitude}, ${r.longitude}',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        if (r.addressDetail != null && r.addressDetail!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              r.addressDetail!,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map, color: Colors.orange, size: 20),
                    onPressed: () async {
                      if (widget.onOpenMap != null) {
                        widget.onOpenMap!(r.latitude, r.longitude);
                      } else {
                        final uri = Uri.parse('https://maps.google.com/?q=${r.latitude},${r.longitude}');
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            if (r.description != null && r.description!.isNotEmpty)
              _InfoRow(
                icon: Icons.notes_outlined,
                label: 'Deskripsi',
                value: r.description!,
              ),

            // ── Foto ─────────────────────────────────────────────────────────
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            const Text(
              '📸 LAMPIRAN FOTO',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (r.photoPaths.isEmpty)
              const Text(
                'Tidak ada foto terlampir',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: r.photoPaths.map((url) {
                  final fullUrl = _buildPhotoUrl(url);
                  return GestureDetector(
                    onTap: () => _openImagePreview(fullUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        fullUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.white10,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
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

            // ── Audio ─────────────────────────────────────────────────────────
            if (widget.report.audioPath != null) ...[
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              const Text(
                '🎙️ REKAMAN AUDIO',
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
                            ? (v) => _audioPlayer.seek(
                                Duration(milliseconds: v.toInt()),
                              )
                            : null,
                      ),
                    ),
                    Text(
                      '${_position.inMinutes.toString().padLeft(2, '0')}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / '
                      '${_duration.inMinutes.toString().padLeft(2, '0')}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // ── Aksi ─────────────────────────────────────────────────────────
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
            _buildActionButtons(r),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ReportModel r) {
    if (r.status == 'sent') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Tingkat Urgensi:',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          PopupMenuButton<int>(
            initialValue: _selectedUrgency,
            color: const Color(0xFF1E2537),
            offset: const Offset(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.white24),
            ),
            onSelected: (v) => setState(() => _selectedUrgency = v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 0,
                child: Text('Rendah', style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 1,
                child: Text('Sedang', style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 2,
                child: Text('Tinggi', style: TextStyle(color: Colors.white)),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedUrgency == null
                        ? 'Pilih Urgensi'
                        : _selectedUrgency == 0
                        ? 'Rendah'
                        : _selectedUrgency == 1
                        ? 'Sedang'
                        : 'Tinggi',
                    style: TextStyle(
                      color: _selectedUrgency == null
                          ? Colors.white38
                          : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white54),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => widget.onUpdateStatus('rejected'),
                child: const Text(
                  'Tolak Laporan',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: _selectedUrgency == null
                    ? null
                    : () => widget.onUpdateStatus('handled', _selectedUrgency),
                child: const Text(
                  'Terima Laporan',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (r.status == 'handled') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => widget.onUpdateStatus('resolved'),
            child: const Text(
              'Selesaikan Laporan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
