import 'package:flutter/material.dart';

class SOSButton extends StatelessWidget {
  final String phase; // 'idle' | 'gracePeriod' | 'broadcasting'
  final int tapCount;
  final int requiredTaps;
  final int graceCountdown;
  final String uploadStatus; // 'idle' | 'sending' | 'sent' | 'failed'
  final VoidCallback onTap;
  final VoidCallback onCancelTap;
  final bool isBanned;

  const SOSButton({
    super.key,
    required this.phase,
    required this.tapCount,
    required this.requiredTaps,
    required this.graceCountdown,
    required this.uploadStatus,
    required this.onTap,
    required this.onCancelTap,
    this.isBanned = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors and labels based on phase
    final isIdle = phase == 'idle';
    final isGrace = phase == 'gracePeriod';
    final isBroadcasting = phase == 'broadcasting';

    Color baseColor = const Color(0xFFEF4444); // Red-500
    if (isGrace) baseColor = const Color(0xFFF59E0B); // Amber-500
    if (isBroadcasting) baseColor = const Color(0xFFDC2626); // Red-600

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow/Pulse
          if (isBroadcasting)
            const PulsingRing(color: Color(0xFFEF4444)),
          
          GestureDetector(
            onTap: isBroadcasting ? onCancelTap : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor,
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.4),
                    blurRadius: isBroadcasting ? 30 : 20,
                    spreadRadius: isBroadcasting ? 10 : 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isIdle) ...[
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      tapCount > 0 ? '$tapCount / $requiredTaps' : 'TEKAN SOS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                  if (isGrace) ...[
                    Text(
                      '$graceCountdown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 64,
                      ),
                    ),
                    const Text(
                      'MEMBATALKAN...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                  if (isBroadcasting) ...[
                    const Icon(Icons.sensors, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    const Text(
                      'SOS AKTIF',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Text(
                      'Mencari Bantuan...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SOSStatusBanner extends StatelessWidget {
  final String uploadStatus;
  final bool isTransmitting;
  final int nextUpdateIn;

  const SOSStatusBanner({
    super.key,
    required this.uploadStatus,
    required this.isTransmitting,
    required this.nextUpdateIn,
  });

  @override
  Widget build(BuildContext context) {
    if (uploadStatus == 'idle') return const SizedBox.shrink();

    Color bgColor = isTransmitting ? const Color(0xFF065F46) : const Color(0xFF991B1B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: bgColor,
      child: Row(
        children: [
          Icon(
            isTransmitting ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isTransmitting ? 'SINYAL SOS TERPANCAR' : 'GANGGUAN TRANSMISI',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  uploadStatus == 'sending'
                      ? 'Menghubungkan ke server...'
                      : 'Update lokasi dalam $nextUpdateIn dtk',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isTransmitting)
            const Text(
              'RETRYING...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class PulsingRing extends StatefulWidget {
  final Color color;
  const PulsingRing({super.key, required this.color});

  @override
  State<PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 200 + (100 * _controller.value),
          height: 200 + (100 * _controller.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 1 - _controller.value),
              width: 4,
            ),
          ),
        );
      },
    );
  }
}
