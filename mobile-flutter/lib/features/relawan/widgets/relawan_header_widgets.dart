import 'package:flutter/material.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/models/user_model.dart';

class HeaderProfile extends StatelessWidget {
  final UserModel user;
  const HeaderProfile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white60 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: user.profilePhotoUrl != null
                ? NetworkImage(user.profilePhotoUrl!)
                : null,
            backgroundColor: const Color(0xFF22C55E).withValues(alpha: 0.2),
            child: user.profilePhotoUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'R',
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, '.tr(context) + user.name.split(' ').first,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.military_tech,
                      size: 14,
                      color: Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.volunteerLevel,
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${user.volunteerPoints} XP',
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class XPBar extends StatelessWidget {
  final int xp;
  const XPBar({super.key, required this.xp});

  /// Warna berdasarkan rank tier
  static Color rankColor(int xp) {
    if (xp >= 5000) return const Color(0xFFDC2626); // Ahli: merah
    if (xp >= 2000) return const Color(0xFFF59E0B); // Veteran: emas
    if (xp >= 500) return const Color(0xFF8B5CF6); // Profesional: ungu
    if (xp >= 100) return const Color(0xFF3B82F6); // Menengah: biru
    return const Color(0xFF22C55E); // Pemula: hijau
  }

  static String rankLabel(int xp) {
    if (xp >= 5000) return 'Ahli';
    if (xp >= 2000) return 'Veteran';
    if (xp >= 500) return 'Profesional';
    if (xp >= 100) return 'Menengah';
    return 'Pemula';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final _ = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white60 : Colors.black54;

    // XP progress logic — 5 tiers
    final nextThreshold = xp < 100
        ? 100
        : xp < 500
        ? 500
        : xp < 2000
        ? 2000
        : xp < 5000
        ? 5000
        : 99999;
    final prevThreshold = xp < 100
        ? 0
        : xp < 500
        ? 100
        : xp < 2000
        ? 500
        : xp < 5000
        ? 2000
        : 5000;
    final progress = nextThreshold == 99999
        ? 1.0
        : (xp - prevThreshold) / (nextThreshold - prevThreshold);

    final color = rankColor(xp);
    final rank = rankLabel(xp);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                rank,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                nextThreshold == 99999
                    ? 'Level Maksimal'.tr(context)
                    : '$xp / $nextThreshold XP',
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nextThreshold == 99999
                ? 'Kamu sudah mencapai level tertinggi!'.tr(context)
                : '${'Selesaikan '.tr(context)}${nextThreshold - xp}${' XP lagi untuk naik ke level berikutnya'.tr(context)}',
            style: TextStyle(color: secondaryText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
