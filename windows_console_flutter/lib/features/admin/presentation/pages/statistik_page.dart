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
  String _selectedPeriod = 'month'; // week | month | year

  // ─── Warna pie chart FIXED per tipe — konsisten di semua period ──────────
  // Setiap tipe insiden selalu mendapat warna yang sama, berapapun jumlah
  // entries dan berapapun urutan dari API.
  static const _typeColorMap = <String, Color>{
    'fire': Color(0xFFEF5350), // merah
    'medical': Color(0xFFAB47BC), // ungu
    'crime': Color(0xFFFF7043), // oranye
    'disaster': Color(0xFF42A5F5), // biru
    'accident': Color(0xFF26C6DA), // cyan
    'general': Color(0xFF66BB6A), // hijau
    'unknown': Color(0xFFFFCA28), // kuning
  };

  // Fallback untuk tipe yang belum terdaftar
  static const _fallbackColor = Color(0xFF90A4AE);

  // Kamus tipe insiden → nama Indonesia (sama dengan instansi, tanpa rescue)
  static const _typeLabels = <String, String>{
    'fire': 'Kebakaran',
    'medical': 'Medis',
    'crime': 'Kriminalitas',
    'disaster': 'Bencana',
    'accident': 'Kecelakaan',
    'general': 'Umum',
    'unknown': 'Tidak Diketahui',
  };

  static const _periodLabels = {
    'week': '1 Minggu',
    'month': '1 Bulan',
    'year': '1 Tahun',
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
    final currentLabel = _periodLabels[_selectedPeriod] ?? '1 Bulan';

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
          // ── Period selector + title ──────────────────────────────────────
          Row(
            children: [
              Text(
                'Statistik ${_periodLabels[_selectedPeriod] ?? ''} Terakhir',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildPeriodDropdown(),
            ],
          ),
          const SizedBox(height: 16),

          // ── KPI Cards ─────────────────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'TOTAL SOS',
                    value: '${_stats.totalSOS}',
                    icon: Icons.sensors,
                    color: Colors.redAccent,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    label: 'SELESAI',
                    value: '${_stats.totalResolved}',
                    icon: Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    label: 'RATA-RATA',
                    value:
                        '${_stats.avgResponseMinutes.toStringAsFixed(1)} mnt',
                    icon: Icons.timer_outlined,
                    color: Colors.blueAccent,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    label: 'ALARM PALSU',
                    value: '${_stats.falseAlarmRate.toStringAsFixed(1)}%',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    label: 'RELAWAN',
                    value: '${_stats.activeVolunteers}',
                    icon: Icons.people_outline,
                    color: Colors.purpleAccent,
                    textTheme: textTheme,
                  ),
                ),
              ],
            ),
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
                              'Tren SOS (${_periodLabels[_selectedPeriod] ?? ''})',
                              style: textTheme.titleMedium,
                            ),
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

              // ── Pie Chart: Distribusi Tipe ────────────────────────────────
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
                                height: 220,
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
                        // ── Spacing antara pie chart dan legend ──────────
                        const SizedBox(height: 32),
                        // Legend
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

    // Hitung maxY dengan margin atas 30%
    final rawMax = spots.isEmpty
        ? 10.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = (rawMax * 1.3)
        .ceilToDouble()
        .clamp(5.0, double.infinity)
        .toDouble();

    // Hitung interval Y agar label tidak terlalu rapat
    final yInterval = (maxY / 5)
        .ceilToDouble()
        .clamp(1.0, double.infinity)
        .toDouble();

    // Hitung interval X (skip labels jika terlalu banyak titik)
    final xInterval = spots.length > 15
        ? (spots.length / 10).ceilToDouble()
        : 1.0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: spots.length <= 1 ? 1 : (spots.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Colors.white24,
            strokeWidth: 0.5,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: xInterval,
              reservedSize: 36,
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _stats.monthly.length) {
                  return const SizedBox();
                }
                final label = _stats.monthly[idx]['month'] as String? ?? '';
                String short = label;
                if (_selectedPeriod == 'year' && label.length >= 7) {
                  // YYYY-MM → tampilkan bulan saja
                  short = label.substring(5); // MM
                } else if (label.length == 10) {
                  // YYYY-MM-DD → tampilkan DD/MM
                  short = '${label.substring(8)}/${label.substring(5, 7)}';
                }
                if (short.length > 10) {
                  short = short.substring(0, 10);
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
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
              interval: yInterval,
              reservedSize: 36,
              getTitlesWidget: (v, meta) {
                if (v == meta.max || v == meta.min) return const SizedBox();
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
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: Colors.white12, width: 1),
            bottom: BorderSide(color: Colors.white12, width: 1),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
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
                  const Color(0xFFFF7043).withValues(alpha: 0.25),
                  const Color(0xFFFF7043).withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final label = idx < _stats.monthly.length
                    ? _stats.monthly[idx]['month'] as String? ?? ''
                    : '';
                return LineTooltipItem(
                  '$label\n${spot.y.toInt()} SOS',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  // ─── Pie Sections — warna FIXED per tipe (konsisten antar period) ─────────
  List<PieChartSectionData> _buildPieSections() {
    final entries = _stats.byType.entries.toList();
    final total = entries.fold(0, (s, e) => s + e.value);
    return entries.map((e) {
      final pct = total == 0 ? 0.0 : e.value / total * 100;
      final color = _typeColorMap[e.key] ?? _fallbackColor;
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: color,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 100,
        titleStyle: TextStyle(
          fontSize: pct < 1 ? 0 : 12,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
        ),
      );
    }).toList();
  }

  // ─── Legend — warna FIXED per tipe ────────────────────────────────────────
  List<Widget> _buildLegend() {
    final entries = _stats.byType.entries.toList();
    return entries.map((e) {
      final color = _typeColorMap[e.key] ?? _fallbackColor;
      final label = _typeLabels[e.key] ?? e.key;
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

// ─── KPI Card ─────────────────────────────────────────────────────────────────

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: textTheme.displaySmall?.copyWith(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
