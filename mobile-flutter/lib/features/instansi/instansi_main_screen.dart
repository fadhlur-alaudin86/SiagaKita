import 'package:flutter/material.dart';
import '../../core/widgets/role_placeholder.dart';
import '../../core/localization/app_localization.dart';
import '../../core/services/session_service.dart';
import '../auth/login_screen.dart';

class InstansiMainScreen extends StatefulWidget {
  const InstansiMainScreen({super.key});

  @override
  State<InstansiMainScreen> createState() => _InstansiMainScreenState();
}

class _InstansiMainScreenState extends State<InstansiMainScreen> {
  int _currentIndex = 0;

  static const _roleColor = Color(0xFFFF7418);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      PlaceholderTab(
        Icons.dashboard_outlined,
        Icons.dashboard,
        'Dashboard'.tr(context),
        'Dashboard'.tr(context),
        'Ringkasan statistik kejadian aktif di wilayah Anda.'.tr(context),
        _roleColor,
      ),
      PlaceholderTab(
        Icons.inbox_outlined,
        Icons.inbox,
        'Laporan'.tr(context),
        'Laporan Masuk'.tr(context),
        'Kelola laporan darurat yang masuk dari masyarakat.'.tr(context),
        Colors.red,
      ),
      PlaceholderTab(
        Icons.people_outline,
        Icons.people,
        'Tim'.tr(context),
        'Tim Lapangan'.tr(context),
        'Kelola penugasan tim dan sumber daya lapangan.'.tr(context),
        Colors.blue,
      ),
      PlaceholderTab(
        Icons.account_balance_outlined,
        Icons.account_balance,
        'Profil'.tr(context),
        'Profil Instansi'.tr(context),
        'Informasi dan pengaturan instansi Anda.'.tr(context),
        Colors.teal,
      ),
    ];
    final tab = tabs[_currentIndex];
    return Scaffold(
      body: RolePlaceholderBody(
        role: 'Instansi Penyelamat'.tr(context),
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
