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
  String _selectedPeriod = 'monthly'; // weekly | monthly | yearly

  // ─── Warna pie chart — identik dengan instansi dashboard ─────────────────
  static const _pieColors = [
    Color(0xFFEF5350), // merah
    Color(0xFF42A5F5), // biru
    Color(0xFFFF7043), // oranye
    Color(0xFFAB47BC), // ungu
    Color(0xFF26C6DA), // cyan
    Color(0xFF66BB6A), // hijau
    Color(0xFFFFCA28), // kuning
  ];

  // Kamus tipe insiden → nama Indonesia (sama dengan instansi)
  static const _typeLabels = <String, String>{
    'fire': 'Kebakaran',
    'medical': 'Medis',
    'crime': 'Kriminalitas',
    'disaster': 'Bencana',
    'accident': 'Kecelakaan',
    'rescue': 'Penyelamatan',
    'general': 'Umum',
    'unknown': 'Tidak Diketahui',
  };

  static const _periodLabels = {
    'weekly': 'Perminggu',
    'monthly': 'Perbulan',
    'yearly': 'Pertahun',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminApiService.getStats(
      widget.token,
      period: _selectedPeriod,
    );
    if (mounted) {
      setState(() {
        _stats = data;
        _loading = false;
      });
    }
  }

  // ─── Period dropdown — sama dengan _buildDropdown instansi riwayat ───────
  Widget _buildPeriodDropdown() {
    final colors = Theme.of(context).colorScheme;
    const boxWidth = 140.0;
    final currentLabel = _periodLabels[_selectedPeriod] ?? 'Perbulan';

    return PopupMenuButton<String>(
      initialValue: _selectedPeriod,
      color: const Color(0xFF1E2537),
      offset: const Offset(0, 48),
      constraints: const BoxConstraints(minWidth: boxWidth, maxWidth: boxWidth),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline),
      ),
      onSelected: (v) {
        if (v != _selectedPeriod) {
          setState(() => _selectedPeriod = v);
          _load();
        }
      },
      itemBuilder: (ctx) => _periodLabels.entries.map((e) {
        return PopupMenuItem<String>(
          value: e.key,
          child: Text(
            e.value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        );
      }).toList(),
      child: Container(
        width: boxWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentLabel,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI Cards ─────────────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                crossAxisCount: 5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                childAspectRatio: 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _KpiCard(
                    label: 'TOTAL SOS',
                    value: '${_stats.totalSOS}',
                    icon: Icons.sensors,
                    color: Colors.redAccent,
                    textTheme: textTheme,
                  ),
                  _KpiCard(
                    label: 'TOTAL SELESAI',
                    value: '${_stats.totalResolved}',
                    icon: Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    textTheme: textTheme,
                  ),
                  _KpiCard(
                    label: 'RATA-RATA RESPONS',
                    value:
                        '${_stats.avgResponseMinutes.toStringAsFixed(1)} mnt',
                    icon: Icons.timer_outlined,
                    color: Colors.blueAccent,
                    textTheme: textTheme,
                  ),
                  _KpiCard(
                    label: 'TINGKAT ALARM PALSU',
                    value: '${_stats.falseAlarmRate.toStringAsFixed(1)}%',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                    textTheme: textTheme,
                  ),
                  _KpiCard(
                    label: 'RELAWAN AKTIF',
                    value: '${_stats.activeVolunteers}',
                    icon: Icons.people_outline,
                    color: Colors.purpleAccent,
                    textTheme: textTheme,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Charts Row ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Line Chart: Tren SOS ──────────────────────────────────────
              Expanded(
                flex: 5,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.show_chart,
                              color: Color(0xFFFF7043),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tren SOS ${_periodLabels[_selectedPeriod] ?? 'Perbulan'}',
                              style: textTheme.titleMedium,
                            ),
                            const Spacer(),
                            _buildPeriodDropdown(),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 280,
                          child: _stats.monthly.isEmpty
                              ? Center(
                                  child: Text(
                                    'Belum ada data statistik',
                                    style: textTheme.bodySmall,
                                  ),
                                )
                              : _buildLineChart(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // ── Pie Chart: Distribusi Tipe — identik dengan instansi ──────
              Expanded(
                flex: 5,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.pie_chart,
                              color: Colors.orangeAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Distribusi Tipe Insiden',
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _stats.byType.isEmpty
                            ? SizedBox(
                                height: 280,
                                child: Center(
                                  child: Text(
                                    'Belum ada data statistik',
                                    style: textTheme.bodySmall,
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 240,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    startDegreeOffset: -90,
                                    sections: _buildPieSections(),
                                    pieTouchData: PieTouchData(
                                      touchCallback: (event, response) {},
                                    ),
                                  ),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOutCubic,
                                ),
                              ),
                        const SizedBox(height: 20),
                        // Legend — sama dengan instansi
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: _buildLegend(),
                        ),
                      ],
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

  // ─── Line Chart ────────────────────────────────────────────────────────────
  Widget _buildLineChart() {
    final spots = _stats.monthly.asMap().entries.map((e) {
      final count = (e.value['count'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), count);
    }).toList();

    final maxY = spots.isEmpty
        ? 10.0
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2)
              .ceilToDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (spots.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: maxY < 5 ? 5 : maxY,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.white10, strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 36,
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _stats.monthly.length) {
                  return const SizedBox();
                }
                final label = _stats.monthly[idx]['month'] as String? ?? '';
                // Truncate label to avoid overlap
                final short = label.length > 7 ? label.substring(0, 7) : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    short,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, meta) {
                if (v == meta.max) return const SizedBox();
                return Text(
                  '${v.toInt()}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                );
              },
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
            spots: spots,
            isCurved: true,
            color: const Color(0xFFFF7043),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: const Color(0xFFFF7043),
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF7043).withValues(alpha: 0.3),
                  const Color(0xFFFF7043).withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  // ─── Pie Sections — warna identik dengan instansi ─────────────────────────
  List<PieChartSectionData> _buildPieSections() {
    final entries = _stats.byType.entries.toList();
    final total = entries.fold(0, (s, e) => s + e.value);
    return entries.asMap().entries.map((e) {
      final pct = total == 0 ? 0.0 : e.value.value / total * 100;
      final color = _pieColors[e.key % _pieColors.length];
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        color: color,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 110,
        titleStyle: TextStyle(
          fontSize: pct < 1 ? 0 : 12,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
        ),
      );
    }).toList();
  }

  // ─── Legend — identik dengan instansi ─────────────────────────────────────
  List<Widget> _buildLegend() {
    final entries = _stats.byType.entries.toList();
    return entries.asMap().entries.map((e) {
      final color = _pieColors[e.key % _pieColors.length];
      final label = _typeLabels[e.value.key] ?? e.value.key;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      );
    }).toList();
  }
}

// ─── KPI Card — menggunakan Card widget seperti instansi ─────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.textTheme,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: textTheme.displaySmall?.copyWith(
                color: color,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
