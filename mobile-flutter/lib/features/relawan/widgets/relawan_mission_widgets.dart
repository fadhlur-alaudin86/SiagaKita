import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/services/incident_service.dart';
import '../../masyarakat/map_screen.dart';

class DutyStatusToggle extends StatelessWidget {
  final bool isOnDuty;
  final ValueChanged<bool> onChanged;
  final bool isDisabled;

  const DutyStatusToggle({
    super.key,
    required this.isOnDuty,
    required this.onChanged,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white60 : Colors.black54;

    final effectiveIsOnDuty = isDisabled ? false : isOnDuty;
    final backgroundColor = isDisabled
        ? (isDark ? Colors.white10 : Colors.grey.shade200)
        : (effectiveIsOnDuty
              ? null
              : (isDark
                    ? const Color(0xFF1E293B)
                    : colors.surfaceContainerHighest));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: (effectiveIsOnDuty && !isDisabled)
            ? const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
              )
            : null,
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: (effectiveIsOnDuty && !isDisabled)
            ? [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Icon(
            isDisabled
                ? Icons.lock_outline
                : (effectiveIsOnDuty ? Icons.radar : Icons.radar_outlined),
            color: (effectiveIsOnDuty && !isDisabled)
                ? Colors.white
                : secondaryText,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDisabled
                      ? 'FITUR TERKUNCI'.tr(context)
                      : (effectiveIsOnDuty
                            ? 'DALAM TUGAS'.tr(context)
                            : 'DI LUAR TUGAS'.tr(context)),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: (effectiveIsOnDuty && !isDisabled)
                        ? Colors.white
                        : primaryText,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isDisabled
                      ? 'Dinonaktifkan saat SOS sedang aktif'.tr(context)
                      : (effectiveIsOnDuty
                            ? 'Memantau SOS dalam radius 5 km'.tr(context)
                            : 'Aktifkan untuk menerima panggilan darurat'.tr(
                                context,
                              )),
                  style: TextStyle(
                    color: (effectiveIsOnDuty && !isDisabled)
                        ? Colors.white70
                        : secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: effectiveIsOnDuty,
            onChanged: isDisabled ? null : onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF16A34A),
            inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}

class MissionActiveCard extends StatelessWidget {
  final ActiveResponseModel mission;
  final VoidCallback onComplete;
  final VoidCallback? onNavigateToMap;

  const MissionActiveCard({
    super.key,
    required this.mission,
    required this.onComplete,
    this.onNavigateToMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.crisis_alert, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'MISI SEDANG BERJALAN'.tr(context),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            mission.typeLabel.tr(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (mission.addressDetail != null) ...[
            const SizedBox(height: 4),
            Text(
              mission.addressDetail!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${'Lokasi korban: '.tr(context)}${mission.reporterLatitude.toStringAsFixed(5)}, ${mission.reporterLongitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              if (onNavigateToMap != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.map, color: Colors.white),
                  onPressed: () {
                    MapScreen.targetLocation.value = LatLng(
                      mission.reporterLatitude,
                      mission.reporterLongitude,
                    );
                    onNavigateToMap!();
                  },
                  tooltip: 'Lihat di Peta'.tr(context),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF065F46),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle, size: 18),
              label: Text(
                'SELESAIKAN MISI'.tr(context),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: onComplete,
            ),
          ),
        ],
      ),
    );
  }
}
