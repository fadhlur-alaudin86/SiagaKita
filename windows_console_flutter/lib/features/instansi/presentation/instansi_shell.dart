import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/ws_service.dart';
import 'pages/dashboard_operasi_page.dart';
import 'pages/dispatch_relawan_page.dart';
import 'pages/laporan_masuk_page.dart';
import 'pages/peta_operasional_page.dart';
import 'pages/sos_aktif_page.dart';

enum InstansiMenu {
  dashboard,
  sosAktif,
  laporanMasuk,
  dispatchRelawan,
  petaOperasional,
}

class InstansiShell extends StatefulWidget {
  final String token;
  final WsService ws;

  const InstansiShell({super.key, required this.token, required this.ws});

  @override
  State<InstansiShell> createState() => _InstansiShellState();
}

class _InstansiShellState extends State<InstansiShell> {
  InstansiMenu _activeMenu = InstansiMenu.dashboard;

  static const Map<InstansiMenu, String> _titles = {
    InstansiMenu.dashboard: 'Dashboard Operasi',
    InstansiMenu.sosAktif: 'SOS Aktif',
    InstansiMenu.laporanMasuk: 'Laporan Masuk',
    InstansiMenu.dispatchRelawan: 'Dispatch Relawan',
    InstansiMenu.petaOperasional: 'Peta Operasional',
  };

  Widget _resolvePage() {
    switch (_activeMenu) {
      case InstansiMenu.dashboard:
        return DashboardOperasiPage(token: widget.token, ws: widget.ws);
      case InstansiMenu.sosAktif:
        return SosAktifPage(token: widget.token, ws: widget.ws);
      case InstansiMenu.laporanMasuk:
        return LaporanMasukPage(token: widget.token);
      case InstansiMenu.dispatchRelawan:
        return DispatchRelawanPage(token: widget.token, ws: widget.ws);
      case InstansiMenu.petaOperasional:
        return PetaOperasionalPage(token: widget.token, ws: widget.ws);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.ws,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        body: Row(
          children: [
            _SideNavigation(
              activeMenu: _activeMenu,
              onSelected: (menu) => setState(() => _activeMenu = menu),
              ws: widget.ws,
            ),
            Expanded(
              child: Column(
                children: [
                  _TopHeader(
                    title: _titles[_activeMenu] ?? 'Instansi Console',
                    ws: widget.ws,
                  ),
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
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.activeMenu,
    required this.onSelected,
    required this.ws,
  });

  final InstansiMenu activeMenu;
  final ValueChanged<InstansiMenu> onSelected;
  final WsService ws;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF111827), // Slate 900 - Sidebar
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'SIAGAKITA INSTANSI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _NavItem(
                label: 'Dashboard Operasi',
                icon: Icons.dashboard_outlined,
                selected: activeMenu == InstansiMenu.dashboard,
                onTap: () => onSelected(InstansiMenu.dashboard),
              ),
              _NavItem(
                label: 'SOS Aktif',
                icon: Icons.sensors_outlined,
                selected: activeMenu == InstansiMenu.sosAktif,
                onTap: () => onSelected(InstansiMenu.sosAktif),
              ),
              _NavItem(
                label: 'Laporan Masuk',
                icon: Icons.inbox_outlined,
                selected: activeMenu == InstansiMenu.laporanMasuk,
                onTap: () => onSelected(InstansiMenu.laporanMasuk),
              ),
              _NavItem(
                label: 'Dispatch Relawan',
                icon: Icons.local_shipping_outlined,
                selected: activeMenu == InstansiMenu.dispatchRelawan,
                onTap: () => onSelected(InstansiMenu.dispatchRelawan),
              ),
              _NavItem(
                label: 'Peta Operasional',
                icon: Icons.map_outlined,
                selected: activeMenu == InstansiMenu.petaOperasional,
                onTap: () => onSelected(InstansiMenu.petaOperasional),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 9,
                      color: ws.isConnected
                          ? const Color(0xFF2EAF60)
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ws.isConnected ? 'WS Connected' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFFFF7418) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.title, required this.ws});

  final String title;
  final WsService ws;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E), // Slate 800 - Header
        border: Border(bottom: BorderSide(color: Color(0xFF2A3040))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white),
          ),
          const Spacer(),
          Consumer<WsService>(
            builder: (context, ws, child) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ws.isConnected
                    ? const Color(0xFFE9F8ED)
                    : const Color(0xFFFFE9E9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: ws.isConnected
                        ? const Color(0xFF2EAF60)
                        : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ws.isConnected ? 'Realtime Connected' : 'Offline',
                    style: TextStyle(
                      color: ws.isConnected
                          ? const Color(0xFF2EAF60)
                          : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
