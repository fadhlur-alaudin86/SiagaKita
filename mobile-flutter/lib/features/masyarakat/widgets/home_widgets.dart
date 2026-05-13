import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/localization/app_localization.dart';

class HomeHeader extends StatelessWidget {
  final bool isSOSActive;
  final Color primaryColor;

  const HomeHeader({
    super.key,
    required this.isSOSActive,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 40), // placeholder to balance header
        Expanded(
          child: ValueListenableBuilder<UserModel>(
            valueListenable: UserModel.currentUser,
            builder: (context, user, child) {
              return Column(
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      color: isSOSActive ? Colors.red : primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<bool>(
                    valueListenable: ConnectivityService.isOnline,
                    builder: (_, online, child) {
                      final statusText = isSOSActive
                          ? 'SOS AKTIF'.tr(context)
                          : online
                              ? 'Online'.tr(context)
                              : 'Offline'.tr(context);
                      final statusColor = isSOSActive
                          ? Colors.red
                          : online
                              ? Colors.green
                              : Colors.grey;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${user.roleLabel.tr(context)}',
                            style: TextStyle(
                              color: colors.onSurface.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSOSActive
                        ? 'SOS AKTIF - Ketuk 3× untuk batalkan'.tr(context)
                        : 'Ketuk 3× untuk mengirim SOS'.tr(context),
                    style: TextStyle(
                      color: isSOSActive
                          ? Colors.red.withValues(alpha: 0.8)
                          : colors.onSurface.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight:
                          isSOSActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 40), // placeholder to balance header
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? colors.surfaceContainerHighest.withValues(alpha: 0.4)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
