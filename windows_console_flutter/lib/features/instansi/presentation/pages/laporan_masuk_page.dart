import 'package:flutter/material.dart';

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
  String _filterStatus = 'pending';

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
    if (mounted)
      setState(() {
        _reports = data;
        _loading = false;
      });
  }

  Future<void> _updateStatus(String id, String status) async {
    await IncidentApiService.updateReportStatus(widget.token, id, status);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter
        Row(
          children: [
            for (final f in ['pending', 'reviewed', 'actioned', 'all'])
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
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _load,
            ),
          ],
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
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (_, i) {
                    final r = _reports[i];
                    return Card(
                      color: const Color(0xFF1A2035),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
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
                              'Pelapor: ${r.reporterName}',
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
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            if (r.status == 'pending') ...[
                              _StatusBtn(
                                label: 'Tinjau',
                                color: Colors.blue,
                                onTap: () => _updateStatus(r.id, 'reviewed'),
                              ),
                              _StatusBtn(
                                label: 'Arsip',
                                color: Colors.grey,
                                onTap: () => _updateStatus(r.id, 'actioned'),
                              ),
                            ],
                            if (r.status == 'reviewed')
                              _StatusBtn(
                                label: 'Selesai',
                                color: Colors.green,
                                onTap: () => _updateStatus(r.id, 'actioned'),
                              ),
                          ],
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

class _StatusBtn extends StatelessWidget {
  const _StatusBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
