import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/incident_service.dart';
import '../../masyarakat/map_screen.dart';

class DutyStatusToggle extends StatelessWidget {
  final bool isOnDuty;
  final ValueChanged<bool> onChanged;

  const DutyStatusToggle({
    super.key,
    required this.isOnDuty,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white60 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: isOnDuty
            ? const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
              )
            : null,
        color: isOnDuty
            ? null
            : (isDark
                  ? const Color(0xFF1E293B)
                  : colors.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isOnDuty
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
            isOnDuty ? Icons.radar : Icons.radar_outlined,
            color: isOnDuty ? Colors.white : secondaryText,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnDuty ? 'ON DUTY - Siap Bertugas' : 'OFF DUTY - Istirahat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOnDuty ? Colors.white : primaryText,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isOnDuty
                      ? 'Memantau SOS dalam radius 5 km'
                      : 'Aktifkan untuk menerima panggilan darurat',
                  style: TextStyle(
                    color: isOnDuty ? Colors.white70 : secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnDuty,
            onChanged: onChanged,
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
          const Row(
            children: [
              Icon(Icons.crisis_alert, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'MISI SEDANG BERJALAN',
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
            mission.typeLabel,
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
                  'Lokasi korban: ${mission.reporterLatitude.toStringAsFixed(5)}, '
                  '${mission.reporterLongitude.toStringAsFixed(5)}',
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
                  tooltip: 'Lihat di Peta',
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
              label: const Text(
                'SELESAIKAN MISI',
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
