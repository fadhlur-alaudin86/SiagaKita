import 'package:flutter/material.dart';
import '../../../core/services/incident_service.dart';

class NearbyIncidentCard extends StatelessWidget {
  final NearbyIncident inc;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onDetail;
  final VoidCallback onAccept;

  const NearbyIncidentCard({
    super.key,
    required this.inc,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
    required this.onDetail,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(inc.typeEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inc.typeLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      inc.addressDetail ??
                          '${inc.latitude.toStringAsFixed(4)}, ${inc.longitude.toStringAsFixed(4)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    inc.distanceLabel,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    inc.timeAgo,
                    style: TextStyle(color: secondaryText, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Detail', style: TextStyle(fontSize: 13)),
                  onPressed: onDetail,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text(
                    'TERIMA',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MissionHistoryCard extends StatelessWidget {
  final MissionHistory inc;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;

  const MissionHistoryCard({
    super.key,
    required this.inc,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (inc.responseStatus) {
      'completed' => const Color(0xFF22C55E),
      'rejected' => const Color(0xFFEF4444),
      'waiting_review' => const Color(0xFFF59E0B),
      'canceled' => Colors.grey,
      _ => const Color(0xFF3B82F6),
    };
    final statusLabel = switch (inc.responseStatus) {
      'completed' => 'Selesai (+${inc.xpEarned} XP)',
      'rejected' => 'Ditolak',
      'waiting_review' => 'Menunggu Review',
      'canceled' => 'Dibatalkan',
      _ => inc.responseStatus,
    };

    const typeEmojis = {
      'medical': '🚑',
      'fire': '🔥',
      'crime': '🚨',
      'rescue': '🆘',
      'accident': '🚗',
      'disaster': '🌊',
    };
    final emoji = typeEmojis[inc.incidentType] ?? '⚠️';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inc.incidentType,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatDate(inc.acceptedAt),
                  style: TextStyle(color: secondaryText, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}.${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoStr;
    }
  }
}
