import 'package:flutter/material.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/services/incident_service.dart';

class SOSActionButton extends StatelessWidget {
  final bool isSOSActive;
  final int tapCount;
  final int requiredTaps;
  final Color primaryColor;
  final VoidCallback onTap;

  const SOSActionButton({
    super.key,
    required this.isSOSActive,
    required this.tapCount,
    required this.requiredTaps,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 250,
            height: 250,
            child: RepaintBoundary(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer progress ring (tap count)
                  if (tapCount > 0)
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(
                        value: tapCount / requiredTaps,
                        strokeWidth: 8,
                        backgroundColor: (isSOSActive ? Colors.red : primaryColor)
                            .withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isSOSActive ? Colors.red : primaryColor,
                        ),
                      ),
                    ),
                  // Main SOS / Cancel Button
                  AnimatedScale(
                    scale: tapCount > 0 ? 0.96 : 1.0,
                    duration: const Duration(milliseconds: 80),
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isSOSActive
                              ? [Colors.red, const Color(0xFF8B0000)]
                              : [primaryColor, const Color(0xFFCB5100)],
                        ),
                        border: Border.all(
                          color: (tapCount > 0
                              ? (isSOSActive ? Colors.red : const Color(0xFFCB5100))
                              : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : (isSOSActive ? Colors.red : primaryColor)
                                      .withValues(alpha: 0.3))),
                          width: 8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isSOSActive ? Colors.red : primaryColor)
                                .withValues(
                              alpha: tapCount > 0 ? 0.8 : (isDarkMode ? 0.3 : 0.6),
                            ),
                            blurRadius: tapCount > 0 ? 50 : 30,
                            spreadRadius: tapCount > 0 ? 10 : (isDarkMode ? 5 : 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSOSActive ? Icons.cancel_outlined : Icons.error_outline,
                            color: Colors.white,
                            size: 60,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isSOSActive ? 'AKTIF'.tr(context) : 'SOS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            isSOSActive
                                ? 'KETUK 3× BATALKAN'.tr(context)
                                : 'KETUK 3×'.tr(context),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Tap count indicator dots
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(requiredTaps, (i) {
            final filled = i < tapCount;
            final dotColor = isSOSActive ? Colors.red : primaryColor;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: filled ? 14 : 10,
              height: filled ? 14 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? dotColor : Colors.grey.withValues(alpha: 0.2),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ]
                    : [],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class ActiveSOSBanner extends StatelessWidget {
  final ActiveIncident activeIncident;
  final bool sosTransmitting;
  final int nextUpdateCountdown;
  final DateTime? lastLocationUpdate;
  final ({double lat, double lng, String? address, String? updatedAt})?
      volunteerPosition;
  final Widget Function() uploadStatusBadgeBuilder;

  const ActiveSOSBanner({
    super.key,
    required this.activeIncident,
    required this.sosTransmitting,
    required this.nextUpdateCountdown,
    this.lastLocationUpdate,
    this.volunteerPosition,
    required this.uploadStatusBadgeBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency_share, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SOS AKTIF'.tr(context),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: sosTransmitting ? Colors.greenAccent : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sosTransmitting ? 'Transmitting'.tr(context) : 'Signal Lost'.tr(context),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: sosTransmitting ? Colors.greenAccent : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              uploadStatusBadgeBuilder(),
            ],
          ),
          const SizedBox(height: 6),
          RepaintBoundary(
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 12, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  'Next update: ${nextUpdateCountdown}s'.tr(context),
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
                if (lastLocationUpdate != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined, size: 12, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'Last: ${lastLocationUpdate!.hour.toString().padLeft(2, '0')}:${lastLocationUpdate!.minute.toString().padLeft(2, '0')}:${lastLocationUpdate!.second.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (activeIncident.isBeingHandled) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.red, thickness: 0.5, height: 1),
            const SizedBox(height: 10),
            Text(
              'BANTUAN SEDANG MENUJU LOKASI'.tr(context),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (activeIncident.isHandledByAgency)
                  _buildHandlerBadge(
                    icon: Icons.account_balance,
                    label: 'INSTANSI'.tr(context),
                    color: Colors.blue.shade700,
                  ),
                if (activeIncident.isHandledByAgency && activeIncident.isHandledByVolunteer)
                  const SizedBox(width: 8),
                if (activeIncident.isHandledByVolunteer)
                  _buildHandlerBadge(
                    icon: Icons.person,
                    label: 'RELAWAN'.tr(context),
                    color: Colors.orange.shade800,
                  ),
              ],
            ),
            if (volunteerPosition != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.directions_walk, size: 12, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      volunteerPosition!.address != null
                          ? 'Relawan di: ${volunteerPosition!.address}'
                          : 'Relawan: ${volunteerPosition!.lat.toStringAsFixed(5)}, ${volunteerPosition!.lng.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHandlerBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
