import 'package:flutter/material.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/services/incident_service.dart';
import '../../../core/utils/responsive.dart';

class SOSActionButton extends StatelessWidget {
  final bool isSOSActive;
  final int tapCount;
  final int requiredTaps;
  final Color primaryColor;
  final VoidCallback onTap;
  final bool isDisabled;
  final String? disabledReason;

  const SOSActionButton({
    super.key,
    required this.isSOSActive,
    required this.tapCount,
    required this.requiredTaps,
    required this.primaryColor,
    required this.onTap,
    this.isDisabled = false,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        GestureDetector(
          onTap: isDisabled ? null : onTap,
          child: SizedBox(
            width: 250.w(context),
            height: 250.w(context),
            child: RepaintBoundary(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer progress ring (tap count)
                  if (tapCount > 0 && !isDisabled)
                    SizedBox(
                      width: 240.w(context),
                      height: 240.w(context),
                      child: CircularProgressIndicator(
                        value: tapCount / requiredTaps,
                        strokeWidth: 8.w(context),
                        backgroundColor:
                            (isSOSActive ? Colors.red : primaryColor)
                                .withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isSOSActive ? Colors.red : primaryColor,
                        ),
                      ),
                    ),
                  // Main SOS / Cancel Button
                  AnimatedScale(
                    scale: (tapCount > 0 && !isDisabled) ? 0.96 : 1.0,
                    duration: const Duration(milliseconds: 80),
                    child: Container(
                      width: 220.w(context),
                      height: 220.w(context),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isDisabled
                            ? LinearGradient(
                                colors: [
                                  Colors.grey.shade600,
                                  Colors.grey.shade800,
                                ],
                              )
                            : RadialGradient(
                                colors: isSOSActive
                                    ? [Colors.red, const Color(0xFF8B0000)]
                                    : [primaryColor, const Color(0xFFCB5100)],
                              ),
                        border: Border.all(
                          color: isDisabled
                              ? Colors.white24
                              : (tapCount > 0
                                    ? (isSOSActive
                                          ? Colors.red
                                          : const Color(0xFFCB5100))
                                    : (isDarkMode
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : (isSOSActive
                                                    ? Colors.red
                                                    : primaryColor)
                                                .withValues(alpha: 0.3))),
                          width: 8.w(context),
                        ),
                        boxShadow: isDisabled
                            ? []
                            : [
                                BoxShadow(
                                  color:
                                      (isSOSActive ? Colors.red : primaryColor)
                                          .withValues(
                                            alpha: tapCount > 0
                                                ? 0.8
                                                : (isDarkMode ? 0.3 : 0.6),
                                          ),
                                  blurRadius: tapCount > 0
                                      ? 50.w(context)
                                      : 30.w(context),
                                  spreadRadius: tapCount > 0
                                      ? 10.w(context)
                                      : (isDarkMode
                                            ? 5.w(context)
                                            : 10.w(context)),
                                ),
                              ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDisabled
                                ? Icons.lock_person_outlined
                                : (isSOSActive
                                      ? Icons.cancel_outlined
                                      : Icons.error_outline),
                            color: Colors.white,
                            size: 60.w(context),
                          ),
                          SizedBox(height: 8.h(context)),
                          Text(
                            isDisabled
                                ? 'SOS Terkunci'.tr(context)
                                : (isSOSActive ? 'AKTIF'.tr(context) : 'SOS'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDisabled
                                  ? 24.sp(context)
                                  : 40.sp(context),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (isDisabled && disabledReason != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 4,
                              ),
                              child: Text(
                                disabledReason!.tr(context),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.sp(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Text(
                              isSOSActive
                                  ? 'KETUK 3× BATALKAN'.tr(context)
                                  : 'KETUK 3×'.tr(context),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 9.sp(context),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5.w(context),
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
        SizedBox(height: 20.h(context)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(requiredTaps, (i) {
            final filled = i < tapCount;
            final dotColor = isSOSActive ? Colors.red : primaryColor;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 5.w(context)),
              width: filled ? 14.w(context) : 10.w(context),
              height: filled ? 14.w(context) : 10.w(context),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? dotColor : Colors.grey.withValues(alpha: 0.2),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.5),
                          blurRadius: 6.w(context),
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
      padding: EdgeInsets.symmetric(
        horizontal: 16.w(context),
        vertical: 10.h(context),
      ),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.w(context)),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emergency_share,
                color: Colors.red,
                size: 18.w(context),
              ),
              SizedBox(width: 8.w(context)),
              Expanded(
                child: Text(
                  'SOS AKTIF'.tr(context),
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12.sp(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8.w(context),
                    height: 8.w(context),
                    decoration: BoxDecoration(
                      color: sosTransmitting ? Colors.greenAccent : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4.w(context)),
                  Text(
                    sosTransmitting
                        ? 'Transmitting'.tr(context)
                        : 'Signal Lost'.tr(context),
                    style: TextStyle(
                      fontSize: 10.sp(context),
                      fontWeight: FontWeight.bold,
                      color: sosTransmitting ? Colors.greenAccent : Colors.grey,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 8.w(context)),
              uploadStatusBadgeBuilder(),
            ],
          ),
          SizedBox(height: 6.h(context)),
          RepaintBoundary(
            child: Row(
              children: [
                Icon(
                  Icons.stream,
                  size: 12.w(context),
                  color: Colors.greenAccent,
                ),
                SizedBox(width: 4.w(context)),
                Text(
                  'Streaming Real-time'.tr(context),
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10.sp(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (lastLocationUpdate != null) ...[
                  SizedBox(width: 12.w(context)),
                  Icon(
                    Icons.location_on_outlined,
                    size: 12.w(context),
                    color: Colors.red,
                  ),
                  SizedBox(width: 4.w(context)),
                  Text(
                    'Last: ${lastLocationUpdate!.hour.toString().padLeft(2, '0')}:${lastLocationUpdate!.minute.toString().padLeft(2, '0')}:${lastLocationUpdate!.second.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.8),
                      fontSize: 10.sp(context),
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
              style: TextStyle(
                color: Colors.red,
                fontSize: 10.sp(context),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5.w(context),
              ),
            ),
            SizedBox(height: 6.h(context)),
            Row(
              children: [
                if (activeIncident.isHandledByAgency)
                  _buildHandlerBadge(
                    context: context,
                    icon: Icons.account_balance,
                    label: 'INSTANSI'.tr(context),
                    color: Colors.blue.shade700,
                  ),
                if (activeIncident.isHandledByAgency &&
                    activeIncident.isHandledByVolunteer)
                  const SizedBox(width: 8),
                if (activeIncident.isHandledByVolunteer)
                  _buildHandlerBadge(
                    context: context,
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
                  Icon(
                    Icons.directions_walk,
                    size: 12.w(context),
                    color: Colors.orangeAccent,
                  ),
                  SizedBox(width: 4.w(context)),
                  Expanded(
                    child: Text(
                      volunteerPosition!.address != null
                          ? 'Relawan di: ${volunteerPosition!.address}'
                          : 'Relawan: ${volunteerPosition!.lat.toStringAsFixed(5)}, ${volunteerPosition!.lng.toStringAsFixed(5)}',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 10.sp(context),
                      ),
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
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8.w(context),
        vertical: 4.h(context),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8.w(context)),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12.w(context)),
          SizedBox(width: 4.w(context)),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.sp(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
