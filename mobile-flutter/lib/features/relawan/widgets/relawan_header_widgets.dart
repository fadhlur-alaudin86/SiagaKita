import 'package:flutter/material.dart';
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
                  'Halo, ${user.name.split(' ').first}',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white60 : Colors.black54;

    // XP progress logic
    final nextThreshold = xp < 100
        ? 100
        : xp < 500
        ? 500
        : xp < 1500
        ? 1500
        : 9999;
    final prevThreshold = xp < 100
        ? 0
        : xp < 500
        ? 100
        : xp < 1500
        ? 500
        : 1500;
    final progress = nextThreshold == 9999
        ? 1.0
        : (xp - prevThreshold) / (nextThreshold - prevThreshold);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Progress Level',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                nextThreshold == 9999
                    ? 'Level Maksimal'
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
              color: const Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nextThreshold == 9999
                ? 'Kamu sudah mencapai level tertinggi!'
                : 'Selesaikan ${nextThreshold - xp} XP lagi untuk naik ke level berikutnya',
            style: TextStyle(color: secondaryText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
