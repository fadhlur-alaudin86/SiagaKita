import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';
import '../../core/services/incident_service.dart';
import 'widgets/relawan_card_widgets.dart';

class RelawanHistoryScreen extends StatefulWidget {
  final String accessToken;

  const RelawanHistoryScreen({super.key, required this.accessToken});

  @override
  State<RelawanHistoryScreen> createState() => _RelawanHistoryScreenState();
}

class _RelawanHistoryScreenState extends State<RelawanHistoryScreen> {
  List<MissionHistory> _missionHistory = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final history = await IncidentService.getMyHistory(
        accessToken: widget.accessToken,
      );
      if (mounted) {
        setState(() {
          _missionHistory = history;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Riwayat Misi'.tr(context),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _buildBody(isDark, primaryText, secondaryText),
    );
  }

  Widget _buildBody(bool isDark, Color primaryText, Color secondaryText) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_missionHistory.isEmpty) {
      return _emptyPlaceholder(
        Icons.history,
        'Belum ada riwayat misi',
        'Riwayat SOS yang kamu tangani akan muncul di sini',
        isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _missionHistory.length,
        itemBuilder: (context, index) => MissionHistoryCard(
          inc: _missionHistory[index],
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
      ),
    );
  }


  Widget _emptyPlaceholder(
    IconData icon,
    String title,
    String subtitle,
    bool isDark,
  ) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.5)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white38 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white24 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
