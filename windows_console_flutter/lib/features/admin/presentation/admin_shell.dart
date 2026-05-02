import 'package:flutter/material.dart';

import '../../../core/services/ws_service.dart';
import 'pages/kyc_relawan_page.dart';
import 'pages/user_management_page.dart';
import 'pages/gamifikasi_page.dart';
import 'pages/statistik_page.dart';
import 'pages/pendaftaran_akun_page.dart';

enum AdminMenu { kyc, users, pendaftaran, gamifikasi, statistik }

class AdminShell extends StatefulWidget {
  final String token;
  final String role;
  final String name;
  final WsService ws;

  const AdminShell({super.key, required this.token, required this.role, required this.name, required this.ws});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminMenu _active = AdminMenu.kyc;

  static const _titles = {
    AdminMenu.kyc: 'KYC & Verifikasi Relawan',
    AdminMenu.users: 'Manajemen Pengguna',
    AdminMenu.pendaftaran: 'Pendaftaran Akun Khusus',
    AdminMenu.gamifikasi: 'Master Data Gamifikasi',
    AdminMenu.statistik: 'Statistik & Analitik',
  };

  Widget _resolvePage() => switch (_active) {
        AdminMenu.kyc => KycRelawanPage(token: widget.token),
        AdminMenu.users => UserManagementPage(token: widget.token),
        AdminMenu.pendaftaran => PendaftaranAkunPage(token: widget.token, role: widget.role),
        AdminMenu.gamifikasi => GamifikasiPage(token: widget.token),
        AdminMenu.statistik => StatistikPage(token: widget.token),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _AdminSideNav(
            activeMenu: _active,
            name: widget.name,
            onSelected: (m) => setState(() => _active = m),
          ),
          Expanded(
            child: Column(
              children: [
                _AdminTopHeader(title: _titles[_active] ?? 'Admin Console'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _resolvePage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Admin Sidebar ────────────────────────────────────────────────────────────

class _AdminSideNav extends StatelessWidget {
  const _AdminSideNav({required this.activeMenu, required this.name, required this.onSelected});
  final AdminMenu activeMenu;
  final String name;
  final ValueChanged<AdminMenu> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF111827),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings,
                        color: Color(0xFFFF7418), size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'SIAGAKITA ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(name.isNotEmpty ? name : 'System Administrator',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('MANAJEMEN',
                    style: TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        letterSpacing: 1.5)),
              ),
              _AdminNavItem(
                label: 'KYC Relawan',
                icon: Icons.badge_outlined,
                badge: '3',
                selected: activeMenu == AdminMenu.kyc,
                onTap: () => onSelected(AdminMenu.kyc),
              ),
              _AdminNavItem(
                label: 'Manajemen Pengguna',
                icon: Icons.people_outlined,
                selected: activeMenu == AdminMenu.users,
                onTap: () => onSelected(AdminMenu.users),
              ),
              _AdminNavItem(
                label: 'Pendaftaran Akun',
                icon: Icons.person_add_outlined,
                selected: activeMenu == AdminMenu.pendaftaran,
                onTap: () => onSelected(AdminMenu.pendaftaran),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('SISTEM',
                    style: TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        letterSpacing: 1.5)),
              ),
              _AdminNavItem(
                label: 'Gamifikasi',
                icon: Icons.emoji_events_outlined,
                selected: activeMenu == AdminMenu.gamifikasi,
                onTap: () => onSelected(AdminMenu.gamifikasi),
              ),
              _AdminNavItem(
                label: 'Statistik & Analitik',
                icon: Icons.analytics_outlined,
                selected: activeMenu == AdminMenu.statistik,
                onTap: () => onSelected(AdminMenu.statistik),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xFF2EAF60), size: 9),
                    SizedBox(width: 8),
                    Text('Sistem Online',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  const _AdminNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? const Color(0xFFFF7418) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(badge!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Admin Top Header ─────────────────────────────────────────────────────────

class _AdminTopHeader extends StatelessWidget {
  const _AdminTopHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        border: Border(bottom: BorderSide(color: Color(0xFF2A3040))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.admin_panel_settings, color: Color(0xFFFF7418), size: 16),
          const SizedBox(width: 6),
          const Text('Admin Mode',
              style: TextStyle(color: Color(0xFFFF7418), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
