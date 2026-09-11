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
  final bool isCooldown;
  final int cooldownSeconds;

  const SOSActionButton({
    super.key,
    required this.isSOSActive,
    required this.tapCount,
    required this.requiredTaps,
    required this.primaryColor,
    required this.onTap,
    this.isDisabled = false,
    this.disabledReason,
    this.isCooldown = false,
    this.cooldownSeconds = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Clamp button size agar tidak overflow di layar kecil (min 160, max 220)
    final btnSize = 220.cw(context, min: 160, max: 220);
    final ringSize = btnSize + 20;
    final iconSize = 60.cw(context, min: 42, max: 60);
    final labelSize = 40.csp(context, min: 28, max: 40);
    final subSize = 9.csp(context, min: 8, max: 11);

    final bool locked = isDisabled || isCooldown;

    return Column(
      children: [
        GestureDetector(
          onTap: locked ? null : onTap,
          child: SizedBox(
            width: ringSize,
            height: ringSize,
            child: RepaintBoundary(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cooldown progress ring
                  if (isCooldown)
                    SizedBox(
                      width: ringSize - 10,
                      height: ringSize - 10,
                      child: CircularProgressIndicator(
                        value: cooldownSeconds / 60,
                        strokeWidth: 8.cw(context, min: 5, max: 8),
                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.grey,
                        ),
                      ),
                    ),
                  // Outer progress ring (tap count)
                  if (tapCount > 0 && !locked)
                    SizedBox(
                      width: ringSize - 10,
                      height: ringSize - 10,
                      child: CircularProgressIndicator(
                        value: tapCount / requiredTaps,
                        strokeWidth: 8.cw(context, min: 5, max: 8),
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
                    scale: (tapCount > 0 && !locked) ? 0.96 : 1.0,
                    duration: const Duration(milliseconds: 80),
                    child: Container(
                      width: btnSize,
                      height: btnSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: locked
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
                          color: locked
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
                          width: 8.cw(context, min: 5, max: 8),
                        ),
                        boxShadow: locked
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
                                      ? 50.cw(context, min: 30, max: 50)
                                      : 30.cw(context, min: 18, max: 30),
                                  spreadRadius: tapCount > 0
                                      ? 10.cw(context, min: 5, max: 10)
                                      : (isDarkMode
                                            ? 5.cw(context, min: 3, max: 5)
                                            : 10.cw(context, min: 5, max: 10)),
                                ),
                              ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCooldown
                                ? Icons.hourglass_top_rounded
                                : (isDisabled
                                      ? Icons.lock_person_outlined
                                      : (isSOSActive
                                            ? Icons.cancel_outlined
                                            : Icons.error_outline)),
                            color: Colors.white,
                            size: iconSize,
                          ),
                          SizedBox(height: 8.h(context)),
                          if (isCooldown) ...[
                            Text(
                              '${cooldownSeconds}s',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: labelSize,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 4,
                              ),
                              child: Text(
                                'SOS Terkunci'.tr(context),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.csp(context, min: 8, max: 11),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              isDisabled
                                  ? 'SOS Terkunci'.tr(context)
                                  : (isSOSActive ? 'AKTIF'.tr(context) : 'SOS'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isDisabled
                                    ? 24.csp(context, min: 16, max: 24)
                                    : labelSize,
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
                                    fontSize: 10.csp(context, min: 8, max: 11),
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
                                  fontSize: subSize,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                          ],
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
              width: filled
                  ? 14.cw(context, min: 10, max: 14)
                  : 10.cw(context, min: 7, max: 10),
              height: filled
                  ? 14.cw(context, min: 10, max: 14)
                  : 10.cw(context, min: 7, max: 10),
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
  final String uploadStatus;

  const ActiveSOSBanner({
    super.key,
    required this.activeIncident,
    required this.sosTransmitting,
    required this.nextUpdateCountdown,
    this.lastLocationUpdate,
    this.volunteerPosition,
    required this.uploadStatusBadgeBuilder,
    required this.uploadStatus,
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
                size: 18.cw(context, min: 14, max: 18),
              ),
              SizedBox(width: 8.w(context)),
              Expanded(
                child: Text(
                  'SOS AKTIF'.tr(context),
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12.csp(context, min: 10, max: 13),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8.cw(context, min: 6, max: 8),
                    height: 8.cw(context, min: 6, max: 8),
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
                      fontSize: 9.csp(context, min: 8, max: 10),
                      fontWeight: FontWeight.bold,
                      color: sosTransmitting ? Colors.greenAccent : Colors.grey,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 6.w(context)),
              uploadStatusBadgeBuilder(),
            ],
          ),
          SizedBox(height: 6.h(context)),
          RepaintBoundary(
            child: Row(
              children: [
                Icon(
                  Icons.stream,
                  size: 12.cw(context, min: 10, max: 12),
                  color: uploadStatus == 'sending'
                      ? Colors.orangeAccent
                      : Colors.greenAccent,
                ),
                SizedBox(width: 4.w(context)),
                Text(
                  uploadStatus == 'sending'
                      ? 'Mengirim ulang...'.tr(context)
                      : 'Streaming Real-time'.tr(context),
                  style: TextStyle(
                    color: uploadStatus == 'sending'
                        ? Colors.orangeAccent
                        : Colors.greenAccent,
                    fontSize: 10.csp(context, min: 9, max: 11),
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                fontSize: 10.csp(context, min: 9, max: 11),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 6.h(context)),
            // Handler badges (instansi & relawan)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (activeIncident.isHandledByAgency)
                  _buildHandlerBadge(
                    context: context,
                    // Tampilkan nama instansi jika tersedia, fallback ke "Instansi"
                    label: activeIncident.agencyName ?? 'Instansi'.tr(context),
                    color: Colors.blue.shade300,
                  ),
                if (activeIncident.isHandledByVolunteer)
                  _buildHandlerBadge(
                    context: context,
                    label: activeIncident.volunteerNames.isNotEmpty
                        ? activeIncident.volunteerNames.first
                        : 'Relawan'.tr(context),
                    color: Colors.orange.shade300,
                  ),
              ],
            ),
            // Posisi relawan (kontras lebih baik: background gelap + teks putih)
            if (volunteerPosition != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_walk,
                      size: 12,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        volunteerPosition!.address != null
                            ? 'Relawan di: ${volunteerPosition!.address}'
                            : '${volunteerPosition!.lat.toStringAsFixed(5)}, ${volunteerPosition!.lng.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHandlerBadge({
    required BuildContext context,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10.cw(context, min: 7, max: 10),
        vertical: 5.ch(context, min: 3, max: 5),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.cw(context, min: 6, max: 8)),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.csp(context, min: 9, max: 11),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
