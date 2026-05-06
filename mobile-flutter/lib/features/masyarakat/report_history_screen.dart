import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';
import '../../core/services/report_service.dart';
import '../../core/services/incident_service.dart';

class ReportHistoryScreen extends StatefulWidget {
  final String accessToken;
  const ReportHistoryScreen({super.key, required this.accessToken});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<ReportModel> _reports = [];
  bool _isLoadingReports = true;
  String? _errorReports;

  List<ActiveIncident> _sosHistory = [];
  bool _isLoadingSOS = true;
  String? _errorSOS;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadSOSHistory();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoadingReports = true;
      _errorReports = null;
    });
    try {
      final reports = await ReportService.getMyReports(
        accessToken: widget.accessToken,
      );
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoadingReports = false;
        });
      }
    } on ReportException catch (e) {
      if (mounted) {
        setState(() {
          _errorReports = e.message;
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorReports = 'Gagal memuat riwayat laporan.';
          _isLoadingReports = false;
        });
      }
    }
  }

  Future<void> _loadSOSHistory() async {
    setState(() {
      _isLoadingSOS = true;
      _errorSOS = null;
    });
    try {
      final history = await IncidentService.getMyHistory(
        accessToken: widget.accessToken,
      );
      if (mounted) {
        setState(() {
          _sosHistory = history;
          _isLoadingSOS = false;
        });
      }
    } on IncidentException catch (e) {
      if (mounted) {
        setState(() {
          _errorSOS = e.message;
          _isLoadingSOS = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorSOS = 'Gagal memuat riwayat SOS.';
          _isLoadingSOS = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'processing':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Color _urgencyColor(int level) {
    switch (level) {
      case 0:
        return Colors.green;
      case 2:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _categoryIcon(String type) {
    switch (type) {
      case 'fire':
        return Icons.local_fire_department;
      case 'accident':
        return Icons.car_crash;
      case 'disaster':
        return Icons.water_damage;
      case 'crime':
        return Icons.warning_rounded;
      case 'medical':
        return Icons.medical_services;
      default:
        return Icons.report_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0D1B3E);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: Text(
            'Riwayat'.tr(context),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: primaryTextColor),
          bottom: TabBar(
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.5),
            indicatorColor: colors.primary,
            tabs: const [
              Tab(text: 'Laporan'),
              Tab(text: 'SOS Darurat'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadReports();
                _loadSOSHistory();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildReportsBody(colors, isDark),
            _buildSOSBody(colors, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsBody(ColorScheme colors, bool isDark) {
    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorReports != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _errorReports!,
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReports,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 72,
              color: colors.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada laporan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Laporan yang Anda kirim akan muncul di sini.',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (context, index) =>
            _buildReportCard(_reports[index], colors, isDark),
      ),
    );
  }

  Widget _buildSOSBody(ColorScheme colors, bool isDark) {
    if (_isLoadingSOS) return const Center(child: CircularProgressIndicator());

    if (_errorSOS != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _errorSOS!,
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSOSHistory,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_sosHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emergency_outlined,
              size: 72,
              color: colors.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada riwayat SOS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSOSHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sosHistory.length,
        itemBuilder: (context, index) =>
            _buildSOSCard(_sosHistory[index], colors, isDark),
      ),
    );
  }

  Widget _buildReportCard(ReportModel report, ColorScheme colors, bool isDark) {
    final cardColor = isDark ? colors.surfaceContainerHighest : Colors.white;
    final statusColor = _statusColor(report.status);
    final urgencyColor = _urgencyColor(report.urgencyLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                ),
              ],
        border: isDark
            ? Border.all(color: Colors.grey.withValues(alpha: 0.15))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _categoryIcon(report.incidentType),
                    color: urgencyColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _incidentLabel(report.incidentType),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        _formatDate(report.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (report.description != null &&
                report.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                report.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _chip(report.urgencyLabel, urgencyColor),
                const SizedBox(width: 8),
                if (report.photoPaths.isNotEmpty)
                  _chip('${report.photoPaths.length} foto', Colors.blue),
                if (report.audioPath != null) ...[
                  const SizedBox(width: 8),
                  _chip('audio', Colors.purple),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSCard(ActiveIncident sos, ColorScheme colors, bool isDark) {
    final cardColor = isDark ? colors.surfaceContainerHighest : Colors.white;
    final isFalseAlarm = sos.status == 'false_alarm';
    final statusColor = isFalseAlarm ? Colors.orange : Colors.green;
    final statusLabel = isFalseAlarm ? 'Batal / False Alarm' : 'Selesai';

    // Asumsikan darurat selalu tinggi
    const urgencyColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                ),
              ],
        border: isDark
            ? Border.all(color: Colors.grey.withValues(alpha: 0.15))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _categoryIcon(sos.incidentType),
                color: urgencyColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _incidentLabel(sos.incidentType),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(
                      DateTime.tryParse(sos.createdAt) ?? DateTime.now(),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _incidentLabel(String type) {
    const m = {
      'fire': 'Kebakaran',
      'accident': 'Kecelakaan',
      'disaster': 'Bencana Alam',
      'crime': 'Kriminalitas',
      'medical': 'Medis',
    };
    return m[type] ?? type;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
