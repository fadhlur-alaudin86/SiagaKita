import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';

class LaporanMasukPage extends StatefulWidget {
  final String token;
  const LaporanMasukPage({super.key, required this.token});

  @override
  State<LaporanMasukPage> createState() => _LaporanMasukPageState();
}

class _LaporanMasukPageState extends State<LaporanMasukPage> {
  List<ReportModel> _reports = [];
  bool _loading = true;
  String _filterStatus = 'sent';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await IncidentApiService.getReports(
      widget.token,
      status: _filterStatus == 'all' ? null : _filterStatus,
    );
    if (mounted) {
      setState(() {
        _reports = data;
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    await IncidentApiService.updateReportStatus(widget.token, id, status);
    _load();
  }

  void _showDetailDialog(ReportModel report) {
    showDialog(
      context: context,
      builder: (_) => _ReportDetailDialog(
        report: report,
        onUpdateStatus: (s) {
          Navigator.pop(context);
          _updateStatus(report.id, s);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      'sent',
      'accepted',
      'handled',
      'resolved',
      'rejected',
      'canceled',
      'all'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.toUpperCase()),
                    selected: _filterStatus == f,
                    onSelected: (_) => setState(() {
                      _filterStatus = f;
                      _load();
                    }),
                    selectedColor: const Color(0xFFFF7418),
                    labelStyle: TextStyle(
                      color: _filterStatus == f ? Colors.white : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: const Color(0xFF1A2035),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54),
                onPressed: _load,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada laporan ditemukan',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _reports.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, i) {
                        final r = _reports[i];
                        return Card(
                          color: const Color(0xFF1A2035),
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
                              backgroundColor:
                                  Colors.orange.withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.description_outlined,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  r.incidentType.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  r.urgencyLabel,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Pelapor: ${r.reporterName} • Status: ${r.status.toUpperCase()}',
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
                            trailing: r.status == 'sent'
                                ? const Icon(Icons.new_releases,
                                    color: Colors.orange)
                                : const Icon(Icons.chevron_right,
                                    color: Colors.white54),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ReportDetailDialog extends StatefulWidget {
  final ReportModel report;
  final Function(String) onUpdateStatus;

  const _ReportDetailDialog({
    required this.report,
    required this.onUpdateStatus,
  });

  @override
  State<_ReportDetailDialog> createState() => _ReportDetailDialogState();
}

class _ReportDetailDialogState extends State<_ReportDetailDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _selectedResponder = 'Agency 1'; // Mock for dispatch

  @override
  void initState() {
    super.initState();
    if (widget.report.audioPath != null) {
      _audioPlayer.setSourceUrl(widget.report.audioPath!);
      _audioPlayer.onDurationChanged
          .listen((d) => setState(() => _duration = d));
      _audioPlayer.onPositionChanged
          .listen((p) => setState(() => _position = p));
      _audioPlayer.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
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
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.green),
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
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds > 0
                      ? _duration.inSeconds.toDouble()
                      : 1.0,
                  onChanged: (v) {
                    _audioPlayer.seek(Duration(seconds: v.toInt()));
                  },
                ),
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
                        color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text('Kategori: ${r.incidentType.toUpperCase()}',
                  style: const TextStyle(color: Colors.white)),
              Text('Urgensi: ${r.urgencyLabel}',
                  style: const TextStyle(color: Colors.white)),
              Text('Pelapor: ${r.reporterName}',
                  style: const TextStyle(color: Colors.white)),
              Text('Status: ${r.status.toUpperCase()}',
                  style: const TextStyle(color: Colors.white)),
              if (r.description != null) ...[
                const SizedBox(height: 12),
                const Text('Deskripsi:',
                    style: TextStyle(color: Colors.white70)),
                Text(r.description!,
                    style: const TextStyle(color: Colors.white)),
              ],
              if (r.photoPaths.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Lampiran Foto:',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: r.photoPaths.map((url) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, _) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.white10,
                          child: const Icon(Icons.broken_image,
                              color: Colors.white54),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              _buildAudioPlayer(),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final r = widget.report;
    if (r.status == 'sent') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => widget.onUpdateStatus('rejected'),
            child: const Text('Tolak Laporan',
                style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => widget.onUpdateStatus('accepted'),
            child: const Text('Terima Laporan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    } else if (r.status == 'accepted') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tugaskan Personil:',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedResponder,
                  dropdownColor: const Color(0xFF1A2035),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: ['Agency 1', 'Relawan A', 'Relawan B']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedResponder = v!),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () => widget.onUpdateStatus('handled'),
                child: const Text('Tugaskan',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      );
    } else if (r.status == 'handled') {
      return Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Menunggu personil yang ditugaskan mengirim bukti selesai sebelum insiden dapat ditutup.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            onPressed: null, // Disabled per requirement
            child: const Text('Selesaikan',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
