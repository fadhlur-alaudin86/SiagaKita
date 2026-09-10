import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/ws_service.dart';
import '../../../../core/localization/app_localization.dart';

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
        _stats = stats ?? StatsModel.empty();
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
    // final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI Cards ────────────────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                childAspectRatio: 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _KpiCard(
                    label: 'SOS AKTIF'.tr(context),
                    value: '${_recentSOS.length}',
                    icon: Icons.sensors,
                    color: Colors.redAccent,
                    pulse: _recentSOS.isNotEmpty,
                  ),
                  _KpiCard(
                    label: 'TOTAL DISELESAIKAN'.tr(context),
                    value: '${_stats.totalResolved}',
                    icon: Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                  ),
                  _KpiCard(
                    label: 'RATA-RATA RESPONS'.tr(context),
                    value:
                        '${_stats.avgResponseMinutes.toStringAsFixed(1)} ${'mnt'.tr(context)}',
                    icon: Icons.timer_outlined,
                    color: Colors.blueAccent,
                  ),
                  _KpiCard(
                    label: 'TINGKAT ALARM PALSU'.tr(context),
                    value: '${_stats.falseAlarmRate.toStringAsFixed(1)}%',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Bottom Panels ─────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SOS list terbaru
              Expanded(
                flex: 5,
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.sensors,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'SOS Terbaru'.tr(context),
                              style: textTheme.titleMedium,
                            ),
                            const Spacer(),
                            if (_recentSOS.isNotEmpty)
                              FilledButton.icon(
                                onPressed: AudioService.stop,
                                icon: const Icon(Icons.volume_off, size: 16),
                                label: Text('Hentikan Alarm'.tr(context)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(
                                    alpha: 0.1,
                                  ),
                                  foregroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Colors.red.withValues(alpha: 0.2),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      SizedBox(
                        height: 400,
                        child: _recentSOS.isEmpty
                            ? Center(
                                child: Text(
                                  'Sistem Terpantau Aman'.tr(context),
                                  style: textTheme.bodyMedium,
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: _recentSOS.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(indent: 70),
                                itemBuilder: (context, i) {
                                  final inc = _recentSOS[i];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 4,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      inc.typeLabelId.tr(context),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${'Dilaporkan'.tr(context)} ${inc.timeAgo}',
                                      style: textTheme.bodySmall,
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

              const SizedBox(width: 24),

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
                              'Distribusi Tipe SOS'.tr(context),
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _stats.byType.isEmpty
                            ? SizedBox(
                                height: 400,
                                child: Center(
                                  child: Text(
                                    'Belum ada data statistik'.tr(context),
                                    style: textTheme.bodySmall,
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 320,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    startDegreeOffset: -90,
                                    sections: _buildSections(),
                                    pieTouchData: PieTouchData(
                                      touchCallback: (event, response) {},
                                    ),
                                  ),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOutCubic,
                                ),
                              ),
                        const SizedBox(height: 20),
                        // Legend
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: _buildLegend(context),
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

  // Kamus tipe insiden → nama Indonesia
  static const _typeLabels = <String, String>{
    'fire': 'Kebakaran',
    'medical': 'Medis',
    'crime': 'Kriminalitas',
    'disaster': 'Bencana',
    'accident': 'Kecelakaan',
    'general': 'Umum',
    'unknown': 'Tidak Diketahui',
  };

  // Warna FIXED per tipe — konsisten di semua halaman
  static const _typeColorMap = <String, Color>{
    'fire': Color(0xFFEF5350), // merah
    'medical': Color(0xFFAB47BC), // ungu
    'crime': Color(0xFFFF7043), // oranye
    'disaster': Color(0xFF42A5F5), // biru
    'accident': Color(0xFF26C6DA), // cyan
    'general': Color(0xFF66BB6A), // hijau
    'unknown': Color(0xFFFFCA28), // kuning
  };
  static const _fallbackColor = Color(0xFF90A4AE);

  List<PieChartSectionData> _buildSections() {
    final entries = _stats.byType.entries.toList();
    final total = entries.fold(0, (s, e) => s + e.value);
    return entries.map((e) {
      final pct = total == 0 ? 0.0 : e.value / total * 100;
      final color = _typeColorMap[e.key] ?? _fallbackColor;
      return PieChartSectionData(
        value: e.value.toDouble(),
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

  List<Widget> _buildLegend(BuildContext context) {
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
            label.tr(context),
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
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
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: pulse
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              )
            : null,
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
                const Spacer(),
                if (pulse)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: textTheme.displaySmall?.copyWith(
                color: color,
                fontSize: 32,
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

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'verified' => Colors.greenAccent,
      'unverified' => Colors.redAccent,
      _ => Colors.orangeAccent,
    };
    final text = switch (label) {
      'verified' => 'VERIFIED',
      'unverified' => 'UNVERIFIED',
      _ => 'STANDARD',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
