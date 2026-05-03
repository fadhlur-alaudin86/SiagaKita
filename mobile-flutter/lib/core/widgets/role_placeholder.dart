import 'package:flutter/material.dart';
import '../localization/app_localization.dart';

/// Data model untuk tab di placeholder screens
class PlaceholderTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String name;
  final String description;
  final Color color;

  const PlaceholderTab(
    this.icon,
    this.activeIcon,
    this.label,
    this.name,
    this.description,
    this.color,
  );
}

/// Widget body placeholder yang dipakai oleh semua role screen
class RolePlaceholderBody extends StatelessWidget {
  final String role;
  final Color roleColor;
  final String tabName;
  final String tabDescription;
  final IconData tabIcon;
  final Color tabColor;
  final VoidCallback onLogout;

  const RolePlaceholderBody({
    super.key,
    required this.role,
    required this.roleColor,
    required this.tabName,
    required this.tabDescription,
    required this.tabIcon,
    required this.tabColor,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SiagaKita',
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
            const Spacer(),

            // Placeholder Content
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: tabColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tabIcon, size: 64, color: tabColor),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tabName,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tabDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.construction,
                          color: colors.onSurface.withValues(alpha: 0.4),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Halaman ini sedang dalam pengembangan'.tr(context),
                          style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
