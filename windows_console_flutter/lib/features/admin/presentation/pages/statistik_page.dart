import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';

class StatistikPage extends StatefulWidget {
  final String token;
  const StatistikPage({super.key, required this.token});

  @override
  State<StatistikPage> createState() => _StatistikPageState();
}

class _StatistikPageState extends State<StatistikPage> {
  StatsModel _stats = StatsModel.empty();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminApiService.getStats(widget.token);
    if (mounted) {
      setState(() {
        _stats = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI Cards ────────────────────────────────────────────────────
          Row(
            children: [
              _KpiCard(
                label: 'Total SOS',
                value: '${_stats.totalSOS}',
                icon: Icons.sensors,
                color: Colors.red,
              ),
              const SizedBox(width: 16),
              _KpiCard(
                label: 'Selesai',
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
              const SizedBox(width: 16),
              _KpiCard(
                label: 'Relawan Aktif',
                value: '${_stats.activeVolunteers}',
                icon: Icons.people_outline,
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Charts Row ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tren SOS per Bulan (Line Chart)
              Expanded(
                flex: 6,
                child: _ChartCard(
                  title: 'Tren SOS per Bulan',
                  child: _stats.monthly.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada data',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(
                              show: true,
                              getDrawingHorizontalLine: _gridLine,
                              getDrawingVerticalLine: _gridLine,
                            ),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  getTitlesWidget: (v, _) {
                                    final idx = v.toInt();
                                    if (idx < 0 ||
                                        idx >= _stats.monthly.length) {
                                      return const SizedBox();
                                    }
                                    return Text(
                                      _stats.monthly[idx]['month'] as String? ??
                                          '',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (v, _) => Text(
                                    '${v.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _stats.monthly.asMap().entries.map((e) {
                                  final count =
                                      (e.value['count'] as num?)?.toDouble() ??
                                      0;
                                  return FlSpot(e.key.toDouble(), count);
                                }).toList(),
                                isCurved: true,
                                color: const Color(0xFFFF7418),
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(
                                    0xFFFF7418,
                                  ).withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Distribusi Tipe (Pie Chart)
              Expanded(
                flex: 4,
                child: _ChartCard(
                  title: 'Distribusi Tipe Insiden',
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
                            centerSpaceRadius: 36,
                            sections: _buildPieSections(),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.green,
    ];
    final entries = _stats.byType.entries.toList();
    final total = entries.fold(0, (sum, e) => sum + e.value);

    return entries.asMap().entries.map((e) {
      final pct = total == 0 ? 0.0 : e.value.value / total * 100;
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        color: colors[e.key % colors.length],
        title: '${pct.toStringAsFixed(0)}%',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  static FlLine _gridLine(double _) =>
      const FlLine(color: Colors.white10, strokeWidth: 1);
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
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

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2035),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}
