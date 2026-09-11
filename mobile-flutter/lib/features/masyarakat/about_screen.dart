import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0D1B3E);
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black87;
    final cardColor = isDark ? colors.surfaceContainerHighest : Colors.white;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Tentang Aplikasi'.tr(context),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety,
                size: 64,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),

            // App Title & Version
            Text(
              'SIAGAKITA',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Versi 1.0.0 (Build 20)'.tr(context),
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // Description
            Text(
              'SiagaKita adalah platform penanggulangan darurat terpadu yang menghubungkan masyarakat dengan relawan medis dan tim penyelamat dalam satu ekosistem waktu nyata (real-time).'
                  .tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 48),

            // Links
            Card(
              color: cardColor,
              elevation: isDark ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isDark
                    ? BorderSide(color: Colors.grey.withValues(alpha: 0.2))
                    : BorderSide.none,
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.description_outlined,
                      color: Colors.grey,
                    ),
                    title: Text(
                      'Syarat & Ketentuan'.tr(context),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.open_in_new,
                      color: Colors.grey,
                      size: 18,
                    ),
                    onTap: () {},
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: isDark
                        ? Colors.grey.withValues(alpha: 0.2)
                        : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.grey,
                    ),
                    title: Text(
                      'Kebijakan Privasi'.tr(context),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.open_in_new,
                      color: Colors.grey,
                      size: 18,
                    ),
                    onTap: () {},
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: isDark
                        ? Colors.grey.withValues(alpha: 0.2)
                        : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: const Icon(Icons.code, color: Colors.grey),
                    title: Text(
                      'Lisensi Perangkat Lunak'.tr(context),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            Text(
              '© 2026 Tim SiagaKita\nDibuat untuk Kemanusiaan'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
