import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/ws_service.dart';

class DashboardOperasiPage extends StatefulWidget {
  final String token;
  final WsService ws;
  const DashboardOperasiPage({
    super.key,
    required this.token,
    required this.ws,
  });

  @override
  State<DashboardOperasiPage> createState() => _DashboardOperasiPageState();
}

class _DashboardOperasiPageState extends State<DashboardOperasiPage> {
  StatsModel _stats = StatsModel.empty();
  List<IncidentModel> _recentSOS = [];
  bool _loading = true;
  StreamSubscription<WsMessage>? _wsSub;

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
          msg.event == WsEvent.rescueAccepted ||
          msg.event == WsEvent.sosStatusUpdate ||
          msg.event == WsEvent.connected) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await AdminApiService.getStats(widget.token);
    final incidents = await IncidentApiService.getActiveIncidents(widget.token);
    if (mounted) {
      setState(() {
        _stats = stats;
        _recentSOS = incidents;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── KPI Cards ────────────────────────────────────────────────────────
        Row(
          children: [
            _KpiCard(
              label: 'SOS Aktif',
              value: '${_recentSOS.length}',
              icon: Icons.sensors,
              color: Colors.red,
              pulse: _recentSOS.isNotEmpty,
            ),
            const SizedBox(width: 16),
            _KpiCard(
              label: 'Total Diselesaikan',
              value: '${_stats.totalResolved}',
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            const SizedBox(width: 16),
            _KpiCard(
              label: 'Avg Respons',
              value: '${_stats.avgResponseMinutes.toStringAsFixed(1)} mnt',
              icon: Icons.timer_outlined,
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
            _KpiCard(
              label: 'False Alarm',
              value: '${_stats.falseAlarmRate.toStringAsFixed(1)}%',
              icon: Icons.warning_amber_outlined,
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Bottom Panels ─────────────────────────────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SOS list terbaru
              Expanded(
                flex: 5,
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
                            const Icon(
                              Icons.sensors,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'SOS Terbaru',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_recentSOS.isNotEmpty)
                              GestureDetector(
                                onTap: AudioService.stop,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.volume_off,
                                        color: Colors.red,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Matikan Alarm',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      Expanded(
                        child: _recentSOS.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tidak ada SOS aktif 🟢',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _recentSOS.length,
                                separatorBuilder: (context, index) => const Divider(
                                  color: Colors.white10,
                                  height: 1,
                                ),
                                itemBuilder: (context, i) {
                                  final inc = _recentSOS[i];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                    ),
                                    title: Text(
                                      inc.typeLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      inc.timeAgo,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: _TrustBadge(
                                      label: inc.trustLabel,
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

              // Pie Chart distribusi
              Expanded(
                flex: 4,
                child: Card(
                  color: const Color(0xFF1A2035),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Distribusi Tipe SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _stats.byType.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Belum ada data',
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                )
                              : PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 30,
                                    sections: _buildSections(),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections() {
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    final entries = _stats.byType.entries.toList();
    final total = entries.fold(0, (s, e) => s + e.value);
    return entries.asMap().entries.map((e) {
      final pct = total == 0 ? 0.0 : e.value.value / total * 100;
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        color: colors[e.key % colors.length],
        title: '${pct.toStringAsFixed(0)}%',
        radius: 70,
        titleStyle: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.pulse = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pulse ? color : color.withValues(alpha: 0.2),
            width: pulse ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'verified' => Colors.green,
      'unverified' => Colors.red,
      _ => Colors.orange,
    };
    final text = switch (label) {
      'verified' => '✓ Verified',
      'unverified' => '⚠ Unverified',
      _ => '~ Standard',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
