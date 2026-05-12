import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';

class RiwayatSosPage extends StatefulWidget {
  final String token;
  const RiwayatSosPage({super.key, required this.token});

  @override
  State<RiwayatSosPage> createState() => _RiwayatSosPageState();
}

class _RiwayatSosPageState extends State<RiwayatSosPage> {
  List<IncidentModel> _allIncidents = [];
  List<IncidentModel> _filteredIncidents = [];
  bool _loading = true;
  String? _currentAgencyId;
  String _selectedFilter = 'Semua';

  final List<String> _filters = [
    'Semua',
    'Selesai (Kami)',
    'Selesai (Instansi Lain)',
    'Selesai (Relawan)',
    'False Alarm',
    'Dibatalkan',
  ];

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
        _applyFilter(_selectedFilter);
      });
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'Semua') {
        _filteredIncidents = List.from(_allIncidents);
      } else if (filter == 'Selesai (Kami)') {
        _filteredIncidents = _allIncidents
            .where(
              (inc) =>
                  inc.status == 'resolved' &&
                  inc.handledByAgencyId == _currentAgencyId,
            )
            .toList();
      } else if (filter == 'Selesai (Instansi Lain)') {
        _filteredIncidents = _allIncidents
            .where(
              (inc) =>
                  inc.status == 'resolved' &&
                  inc.handledByAgencyId != null &&
                  inc.handledByAgencyId != _currentAgencyId,
            )
            .toList();
      } else if (filter == 'Selesai (Relawan)') {
        _filteredIncidents = _allIncidents
            .where(
              (inc) =>
                  inc.status == 'resolved' && inc.handledByAgencyId == null,
            )
            .toList();
      } else if (filter == 'False Alarm') {
        _filteredIncidents = _allIncidents
            .where((inc) => inc.status == 'false_alarm')
            .toList();
      } else if (filter == 'Dibatalkan') {
        _filteredIncidents = _allIncidents
            .where((inc) => inc.status == 'cancel')
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSelected = filter == _selectedFilter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => _applyFilter(filter),
                  backgroundColor: const Color(0xFF1A2035),
                  selectedColor: const Color(0xFFFF7418),
                  checkmarkColor: Colors.white,
                ),
              );
            }).toList(),
          ),
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
                  itemBuilder: (context, index) {
                    final inc = _filteredIncidents[index];
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              inc.typeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            _StatusBadge(status: inc.status),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pelapor: ${inc.reporterName} (${inc.reporterPhone})',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Diperbarui: ${DateFormat('dd MMM yyyy, HH:mm').format(inc.updatedAt)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case 'resolved':
        color = Colors.green;
        text = 'Selesai';
        break;
      case 'false_alarm':
        color = Colors.orange;
        text = 'False Alarm';
        break;
      case 'cancel':
        color = Colors.grey;
        text = 'Dibatalkan';
        break;
      default:
        color = Colors.blue;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
