import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';
import '../../core/services/report_service.dart';
import '../../core/services/incident_service.dart';

class ReportHistoryScreen extends StatefulWidget {
  final String accessToken;
  final bool isNested;
  const ReportHistoryScreen({
    super.key,
    required this.accessToken,
    this.isNested = false,
  });

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
          _reports = reports
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
          _errorReports = 'Gagal memuat riwayat laporan.'.tr(context);
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
      final history = await IncidentService.getReporterHistory(
        accessToken: widget.accessToken,
      );
      if (mounted) {
        setState(() {
          _sosHistory =
              history
                  .where(
                    (s) =>
                        s.status != 'grace_period' &&
                        s.status != 'broadcasting' &&
                        s.status != 'handled',
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
          _errorSOS = 'Gagal memuat riwayat SOS.'.tr(context);
          _isLoadingSOS = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'processing':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'canceled':
        return Colors.grey;
      case 'rejected':
      case 'failed':
        return Colors.red;
      case 'sent':
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Color _urgencyColor(int? level) {
    if (level == null) return Colors.grey;
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

    Widget body = TabBarView(
      children: [
        _buildReportsBody(colors, isDark),
        _buildSOSBody(colors, isDark),
      ],
    );

    if (widget.isNested) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: colors.primary,
              unselectedLabelColor: colors.onSurface.withValues(alpha: 0.5),
              indicatorColor: colors.primary,
              tabs: <Widget>[
                Tab(text: 'Laporan'.tr(context)),
                Tab(text: 'SOS Darurat'.tr(context)),
              ],
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

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
            tabs: <Widget>[
              Tab(text: 'Laporan'.tr(context)),
              Tab(text: 'SOS Darurat'.tr(context)),
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
        body: body,
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
              'Belum ada laporan'.tr(context),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Laporan yang Anda kirim akan muncul di sini.'.tr(context),
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
              'Belum ada riwayat SOS'.tr(context),
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
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    width: 85,
                    child: Center(
                      child: Text(
                        report.getStatusLabel(context),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
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
                // 1. Chip Urgensi (Selalu tampil, '-' jika null)
                Expanded(
                  child: _chip(report.getUrgencyLabel(context), urgencyColor),
                ),
                const SizedBox(width: 6),

                // 2. Chip Foto (Selalu tampil, '-' jika kosong)
                Expanded(
                  child: _chip(
                    report.photoPaths.isNotEmpty
                        ? '${report.photoPaths.length} ${'foto'.tr(context)}'
                        : '-',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 6),

                // 3. Chip Audio (Selalu tampil, '-' jika null)
                Expanded(
                  child: _chip(
                    report.audioPath != null ? 'audio'.tr(context) : '-',
                    Colors.purple,
                  ),
                ),
              ],
            ),
            // ── Tombol Aksi (baris terpisah agar tidak overflow) ──
            if (report.status == 'sent' ||
                report.status == 'pending' ||
                report.status == 'failed') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: report.status == 'failed'
                      ? () => _resendFailedReport(report)
                      : () => _confirmCancelReport(report.id),
                  icon: Icon(
                    report.status == 'failed'
                        ? Icons.refresh
                        : Icons.cancel_outlined,
                    size: 16,
                  ),
                  label: Text(
                    report.status == 'failed'
                        ? 'Kirim Ulang'.tr(context)
                        : 'Batalkan'.tr(context),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: report.status == 'failed'
                        ? Colors.blue
                        : Colors.red,
                    side: BorderSide(
                      color: report.status == 'failed'
                          ? Colors.blue
                          : Colors.red,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmCancelReport(String reportId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Batalkan Laporan?'.tr(context)),
        content: Text(
          'Apakah Anda yakin ingin membatalkan laporan ini? Laporan yang dibatalkan tidak dapat dikembalikan.'
              .tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Tidak'.tr(context),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelReport(reportId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Ya, Batalkan'.tr(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReport(String reportId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await ReportService.cancelReport(
        accessToken: widget.accessToken,
        reportId: reportId,
      );
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan berhasil dibatalkan.'.tr(context)),
          backgroundColor: Colors.green,
        ),
      );
      _loadReports();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan laporan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendFailedReport(ReportModel report) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await ReportService.resendFailedReport(
        accessToken: widget.accessToken,
        failedReport: report,
      );
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan berhasil dikirim ulang.'.tr(context)),
          backgroundColor: Colors.green,
        ),
      );
      _loadReports();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim ulang: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSOSCard(ActiveIncident sos, ColorScheme colors, bool isDark) {
    final cardColor = isDark ? colors.surfaceContainerHighest : Colors.white;
    final isFalseAlarm = sos.status == 'false_alarm';
    final isCanceled = sos.status == 'canceled';
    final statusColor = isFalseAlarm
        ? Colors.red
        : isCanceled
        ? Colors.grey
        : Colors.green;
    final statusLabel = isFalseAlarm
        ? 'Palsu'.tr(context)
        : (isCanceled ? 'Dibatalkan'.tr(context) : 'Selesai'.tr(context));

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
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SizedBox(
                width: 85,
                child: Center(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, {double? width}) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: content);
    }
    return content;
  }

  String _incidentLabel(String type) {
    final m = {
      'fire': 'Kebakaran'.tr(context),
      'accident': 'Kecelakaan'.tr(context),
      'disaster': 'Bencana Alam'.tr(context),
      'crime': 'Kriminalitas'.tr(context),
      'medical': 'Medis'.tr(context),
    };
    return m[type] ?? type;
  }

  String _formatDate(DateTime dt) {
    final localDt = dt.toLocal();
    return '${localDt.day.toString().padLeft(2, '0')}/${localDt.month.toString().padLeft(2, '0')}/${localDt.year} ${localDt.hour.toString().padLeft(2, '0')}:${localDt.minute.toString().padLeft(2, '0')}';
  }
}
