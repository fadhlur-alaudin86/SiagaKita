import 'package:flutter/material.dart';
import '../../core/widgets/role_placeholder.dart';
import '../../core/localization/app_localization.dart';
import '../../core/services/session_service.dart';
import '../auth/login_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  static const _roleColor = Color(0xFFA855F7);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      PlaceholderTab(
        Icons.bar_chart_outlined,
        Icons.bar_chart,
        'Statistik'.tr(context),
        'Statistik Sistem'.tr(context),
        'Pantau data dan tren kejadian seluruh wilayah.'.tr(context),
        _roleColor,
      ),
      PlaceholderTab(
        Icons.manage_accounts_outlined,
        Icons.manage_accounts,
        'User'.tr(context),
        'Kelola Pengguna'.tr(context),
        'Verifikasi, aktifkan, atau nonaktifkan akun pengguna.'.tr(context),
        Colors.blue,
      ),
      PlaceholderTab(
        Icons.folder_open_outlined,
        Icons.folder_open,
        'Laporan'.tr(context),
        'Kelola Laporan'.tr(context),
        'Tinjau dan moderasi semua laporan masuk.'.tr(context),
        Colors.orange,
      ),
      PlaceholderTab(
        Icons.settings_outlined,
        Icons.settings,
        'Setting'.tr(context),
        'Pengaturan Sistem'.tr(context),
        'Konfigurasi sistem dan parameter aplikasi.'.tr(context),
        Colors.grey,
      ),
    ];

    final tab = tabs[_currentIndex];
    return Scaffold(
      body: RolePlaceholderBody(
        role: 'Administrator'.tr(context),
        roleColor: _roleColor,
        tabName: tab.name,
        tabDescription: tab.description,
        tabIcon: tab.activeIcon,
        tabColor: tab.color,
        onLogout: () async {
          await SessionService.clearSession();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (r) => false,
            );
          }
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: _roleColor,
          onTap: (i) => setState(() => _currentIndex = i),
          items: tabs
              .map(
                (t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
