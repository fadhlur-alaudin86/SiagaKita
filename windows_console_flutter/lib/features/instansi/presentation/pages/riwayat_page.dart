import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/constants/api_constants.dart';

class RiwayatPage extends StatelessWidget {
  final String token;
  const RiwayatPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurfaceVariant,
            indicatorColor: colors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            tabs: const [
              Tab(text: 'RIWAYAT SOS'),
              Tab(text: 'RIWAYAT LAPORAN'),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              children: [
                _SosHistoryTab(token: token),
                _ReportHistoryTab(token: token),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOS HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────
class _SosHistoryTab extends StatefulWidget {
  final String token;
  const _SosHistoryTab({required this.token});

  @override
  State<_SosHistoryTab> createState() => _SosHistoryTabState();
}

class _SosHistoryTabState extends State<_SosHistoryTab> {
  List<IncidentModel> _allIncidents = [];
  List<IncidentModel> _filteredIncidents = [];
  bool _loading = true;
  String? _currentAgencyId;

  String _filterStatus = 'Semua';
  String _filterType = 'Semua';
  String _filterTime = 'Semua Waktu';
  String _sortOrder = 'Terbaru';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final profile = await AgencyApiService.getProfile(widget.token);
    _currentAgencyId = profile?['id'];

    final incidents = await IncidentApiService.getHistory(widget.token);

    if (mounted) {
      setState(() {
        _allIncidents = incidents;
        _loading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    setState(() {
      var filtered = List<IncidentModel>.from(_allIncidents);

      // Filter Status
      if (_filterStatus != 'Semua') {
        if (_filterStatus == 'Selesai (Kami)') {
          filtered = filtered
              .where(
                (inc) =>
                    inc.status == 'resolved' &&
                    inc.handledByAgencyId == _currentAgencyId,
              )
              .toList();
        } else if (_filterStatus == 'Selesai (Instansi Lain)') {
          filtered = filtered
              .where(
                (inc) =>
                    inc.status == 'resolved' &&
                    inc.handledByAgencyId != null &&
                    inc.handledByAgencyId != _currentAgencyId,
              )
              .toList();
        } else if (_filterStatus == 'Selesai (Relawan)') {
          filtered = filtered
              .where(
                (inc) =>
                    inc.status == 'resolved' && inc.handledByAgencyId == null,
              )
              .toList();
        } else if (_filterStatus == 'False Alarm') {
          filtered = filtered
              .where((inc) => inc.status == 'false_alarm')
              .toList();
        } else if (_filterStatus == 'Dibatalkan') {
          filtered = filtered.where((inc) => inc.status == 'canceled').toList();
        }
      }

      // Filter Tipe Insiden
      if (_filterType != 'Semua') {
        filtered = filtered
            .where(
              (inc) =>
                  inc.incidentType.toLowerCase() == _filterType.toLowerCase(),
            )
            .toList();
      }

      // Filter Rentang Waktu
      final now = DateTime.now();
      if (_filterTime == 'Hari Ini') {
        filtered = filtered
            .where(
              (inc) =>
                  inc.createdAt.year == now.year &&
                  inc.createdAt.month == now.month &&
                  inc.createdAt.day == now.day,
            )
            .toList();
      } else if (_filterTime == 'Minggu Ini') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        filtered = filtered
            .where(
              (inc) =>
                  inc.createdAt.isAfter(startOfWeek) ||
                  (inc.createdAt.year == startOfWeek.year &&
                      inc.createdAt.month == startOfWeek.month &&
                      inc.createdAt.day == startOfWeek.day),
            )
            .toList();
      } else if (_filterTime == 'Bulan Ini') {
        filtered = filtered
            .where(
              (inc) =>
                  inc.createdAt.year == now.year &&
                  inc.createdAt.month == now.month,
            )
            .toList();
      }

      // Sorting
      if (_sortOrder == 'Terbaru') {
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }

      _filteredIncidents = filtered;
    });
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<T>(
            value: value,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary),
              ),
              filled: true,
              fillColor: colors.surface,
            ),
            dropdownColor: colors.surface,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Dropdowns
        Wrap(
          children: [
            _buildDropdown<String>(
              label: 'Status Laporan',
              value: _filterStatus,
              items: [
                'Semua',
                'Selesai (Kami)',
                'Selesai (Instansi Lain)',
                'Selesai (Relawan)',
                'False Alarm',
                'Dibatalkan',
              ],
              onChanged: (v) {
                if (v != null) {
                  _filterStatus = v;
                  _applyFilters();
                }
              },
            ),
            _buildDropdown<String>(
              label: 'Kategori',
              value: _filterType,
              items: [
                'Semua',
                'Kebakaran',
                'Medis',
                'Kriminalitas',
                'Bencana',
                'Kecelakaan',
              ],
              onChanged: (v) {
                if (v != null) {
                  _filterType = v;
                  _applyFilters();
                }
              },
            ),
            _buildDropdown<String>(
              label: 'Waktu Dibuat',
              value: _filterTime,
              items: ['Semua Waktu', 'Hari Ini', 'Minggu Ini', 'Bulan Ini'],
              onChanged: (v) {
                if (v != null) {
                  _filterTime = v;
                  _applyFilters();
                }
              },
            ),
            _buildDropdown<String>(
              label: 'Urutkan Waktu',
              value: _sortOrder,
              items: ['Terbaru', 'Terlama'],
              onChanged: (v) {
                if (v != null) {
                  _sortOrder = v;
                  _applyFilters();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _filteredIncidents.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada riwayat SOS.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredIncidents.length,
                  padding: const EdgeInsets.only(right: 16),
                  itemBuilder: (context, index) {
                    final inc = _filteredIncidents[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          radius: 24,
                          child: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                        ),
                        title: Row(
                          children: [
                            Text(
                              inc.typeLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Spacer(),
                            _StatusBadge(status: inc.status),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 14, color: Colors.white54),
                              const SizedBox(width: 6),
                              Text(inc.reporterName, style: const TextStyle(color: Colors.white70)),
                              const SizedBox(width: 16),
                              const Icon(Icons.access_time, size: 14, color: Colors.white54),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd MMM yyyy, HH:mm').format(inc.createdAt),
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORT HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ReportHistoryTab extends StatefulWidget {
  final String token;
  const _ReportHistoryTab({required this.token});

  @override
  State<_ReportHistoryTab> createState() => _ReportHistoryTabState();
}

class _ReportHistoryTabState extends State<_ReportHistoryTab> {
  List<ReportModel> _allReports = [];
  List<ReportModel> _filteredReports = [];
  bool _loading = true;

  String _filterStatus = 'Semua';
  String _filterType = 'Semua';
  String _filterUrgency = 'Semua';
  String _filterTime = 'Semua Waktu';
  String _sortOrder = 'Terbaru';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await IncidentApiService.getReports(widget.token);

    if (mounted) {
      setState(() {
        _allReports = data
            .where(
              (r) => ['resolved', 'rejected', 'canceled'].contains(r.status),
            )
            .toList();
        _loading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    setState(() {
      var filtered = List<ReportModel>.from(_allReports);

      // Filter Status
      if (_filterStatus != 'Semua') {
        if (_filterStatus == 'Disetujui') {
          filtered = filtered.where((r) => r.status == 'resolved').toList();
        } else if (_filterStatus == 'Ditolak') {
          filtered = filtered.where((r) => r.status == 'rejected').toList();
        } else if (_filterStatus == 'Dibatalkan') {
          filtered = filtered.where((r) => r.status == 'canceled').toList();
        }
      }

      // Filter Tipe Insiden
      if (_filterType != 'Semua') {
        filtered = filtered
            .where(
              (r) => r.incidentType.toLowerCase() == _filterType.toLowerCase(),
            )
            .toList();
      }

      // Filter Urgensi
      if (_filterUrgency != 'Semua') {
        filtered = filtered
            .where(
              (r) =>
                  r.urgencyLabel.toLowerCase() == _filterUrgency.toLowerCase(),
            )
            .toList();
      }

      // Filter Rentang Waktu
      final now = DateTime.now();
      if (_filterTime == 'Hari Ini') {
        filtered = filtered
            .where(
              (inc) =>
                  inc.createdAt.year == now.year &&
                  inc.createdAt.month == now.month &&
                  inc.createdAt.day == now.day,
            )
            .toList();
      } else if (_filterTime == 'Minggu Ini') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        filtered = filtered
            .where(
              (inc) =>
                  inc.createdAt.isAfter(startOfWeek) ||
                  (inc.createdAt.year == startOfWeek.year &&
                      inc.createdAt.month == startOfWeek.month &&
                      inc.createdAt.day == startOfWeek.day),
            )
            .toList();
      } else if (_filterTime == 'Bulan Ini') {
        filtered = filtered
            .where(
              (inc) =>
                  inc.createdAt.year == now.year &&
                  inc.createdAt.month == now.month,
            )
            .toList();
      }

      // Sorting
      if (_sortOrder == 'Terbaru') {
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }

      _filteredReports = filtered;
    });
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<T>(
            value: value,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary),
              ),
              filled: true,
              fillColor: colors.surface,
            ),
            dropdownColor: colors.surface,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(ReportModel report) {
    showDialog(
      context: context,
      builder: (_) => _ReportHistoryDetailDialog(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Dropdowns
        Wrap(
          children: [
            _buildDropdown<String>(
              label: 'Status Laporan',
              value: _filterStatus,
              items: ['Semua', 'Disetujui', 'Ditolak', 'Dibatalkan'],
              onChanged: (v) {
                if (v != null) {
                  _filterStatus = v;
                  _applyFilters();
                }
              },
            ),
            _buildDropdown<String>(
              label: 'Kategori',
              value: _filterType,
              items: [
                'Semua',
                'Kebakaran',
                'Medis',
                'Kriminalitas',
                'Bencana',
                'Kecelakaan',
              ],
              onChanged: (v) {
                if (v != null) {
                  _filterType = v;
                  _applyFilters();
                }
              },
            ),
            _buildDropdown<String>(
              label: 'Urgensi',
              value: _filterUrgency,
              items: ['Semua', 'Rendah', 'Sedang', 'Tinggi'],
              onChanged: (v) {
                if (v != null) {
                  _filterUrgency = v;
                  _applyFilters();
                }
              },
            ),
            _buildDropdown<String>(
              label: 'Waktu Dibuat',
              value: _filterTime,
              items: ['Semua Waktu', 'Hari Ini', 'Minggu Ini', 'Bulan Ini'],
              onChanged: (v) {
                if (v != null) {
                  _filterTime = v;
                  _applyFilters();
                }
              },
            ),
            _buildDropdown<String>(
              label: 'Urutkan Waktu',
              value: _sortOrder,
              items: ['Terbaru', 'Terlama'],
              onChanged: (v) {
                if (v != null) {
                  _sortOrder = v;
                  _applyFilters();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _filteredReports.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada riwayat laporan.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  itemCount: _filteredReports.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, i) {
                    final r = _filteredReports[i];
                    return Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () => _showDetailDialog(r),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.description_outlined,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r.incidentType.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            _StatusBadge(status: r.status),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Pelapor: ${r.reporterName} • Urgensi: ${r.urgencyLabel}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            if (r.description != null &&
                                r.description!.isNotEmpty)
                              Text(
                                r.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getColor(status).withValues(alpha: 0.3)),
      ),
      child: Text(
        _getText(status),
        style: TextStyle(
          color: _getColor(status),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getColor(String status) {
    return switch (status) {
      'resolved' => Colors.greenAccent,
      'false_alarm' => Colors.orangeAccent,
      'cancelled' || 'canceled' || 'rejected' => Colors.redAccent,
      _ => Colors.grey,
    };
  }

  String _getText(String status) {
    return switch (status) {
      'resolved' => 'SELESAI',
      'false_alarm' => 'FALSE ALARM',
      'cancelled' || 'canceled' => 'DIBATALKAN',
      'rejected' => 'DITOLAK',
      _ => status.toUpperCase(),
    };
  }
}

class _ReportHistoryDetailDialog extends StatefulWidget {
  final ReportModel report;

  const _ReportHistoryDetailDialog({required this.report});

  @override
  State<_ReportHistoryDetailDialog> createState() =>
      _ReportHistoryDetailDialogState();
}

class _ReportHistoryDetailDialogState
    extends State<_ReportHistoryDetailDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.report.audioPath != null) {
      final url = widget.report.audioPath!.startsWith('/uploads')
          ? ApiConstants.baseUrl.replaceAll('/api/v1', '') +
                widget.report.audioPath!
          : widget.report.audioPath!;
      _audioPlayer.setSourceUrl(url);
      _audioPlayer.onDurationChanged.listen(
        (d) => setState(() => _duration = d),
      );
      _audioPlayer.onPositionChanged.listen(
        (p) => setState(() => _position = p),
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
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildAudioPlayer() {
    if (widget.report.audioPath == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rekaman Audio', style: TextStyle(color: Colors.white70)),
          Row(
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
                          _audioPlayer.seek(Duration(milliseconds: v.toInt()));
                        }
                      : null,
                ),
              ),
              Text(
                '${_position.inMinutes.toString().padLeft(2, '0')}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / ${_duration.inMinutes.toString().padLeft(2, '0')}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Dialog(
      backgroundColor: const Color(0xFF1A2035),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detail Laporan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text(
                'Kategori: ${r.incidentType.toUpperCase()}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Urgensi: ${r.urgencyLabel}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Pelapor: ${r.reporterName}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Status: ${r.status.toUpperCase()}',
                style: const TextStyle(color: Colors.white),
              ),
              if (r.description != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Deskripsi:',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  r.description!,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
              if (r.photoPaths.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Lampiran Foto:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: r.photoPaths.map((url) {
                    final fullUrl = url.startsWith('/uploads')
                        ? ApiConstants.baseUrl.replaceAll('/api/v1', '') + url
                        : url;
                    return ClipRRect(
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
                    );
                  }).toList(),
                ),
              ],
              _buildAudioPlayer(),
            ],
          ),
        ),
      ),
    );
  }
}
