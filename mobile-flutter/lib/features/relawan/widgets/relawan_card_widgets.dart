import 'package:flutter/material.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/localization/app_localization.dart';
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
              Icon(inc.typeIcon, size: 22, color: const Color(0xFFFF7418)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inc.typeLabel.tr(context),
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
                    inc.distanceLabel.tr(context),
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    inc.timeAgo.tr(context),
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
                  label: Text(
                    'Detail'.tr(context),
                    style: const TextStyle(fontSize: 13),
                  ),
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
                  label: Text(
                    'TERIMA'.tr(context),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
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
      'completed' =>
        '${'Selesai (+'.tr(context)}${inc.xpEarned}${' XP)'.tr(context)}',
      'rejected' => 'Ditolak'.tr(context),
      'waiting_review' => 'Menunggu Review'.tr(context),
      'canceled' => 'Dibatalkan'.tr(context),
      _ => inc.responseStatus,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7418).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  inc.typeIcon,
                  size: 20,
                  color: const Color(0xFFFF7418),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inc.typeLabel.tr(context),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
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
          if (inc.addressDetail != null && inc.addressDetail!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: secondaryText,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    inc.addressDetail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondaryText, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (inc.durationMinutes != null ||
              (inc.proofPhotoUrl != null && inc.proofPhotoUrl!.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (inc.durationMinutes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${inc.durationMinutes} ${'menit'.tr(context)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (inc.proofPhotoUrl != null && inc.proofPhotoUrl!.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showPhotoDialog(context, inc.proofPhotoUrl!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_outlined,
                            size: 13,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Foto Bukti'.tr(context),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPhotoDialog(BuildContext context, String url) {
    final fullUrl = url.startsWith('http')
        ? url
        : '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}/$url';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Image.network(
                  fullUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text('Gagal memuat gambar'.tr(context)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
