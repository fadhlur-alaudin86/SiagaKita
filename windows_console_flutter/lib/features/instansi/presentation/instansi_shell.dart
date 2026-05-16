import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/ws_service.dart';
import 'pages/dashboard_operasi_page.dart';

import 'pages/laporan_masuk_page.dart';
import 'pages/peta_operasional_page.dart';
import 'pages/sos_aktif_page.dart';
import 'pages/riwayat_page.dart';
import '../../auth/login_screen.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/api_services.dart';
import 'dart:async';

enum InstansiMenu {
  dashboard,
  sosAktif,
  laporanMasuk,
  petaOperasional,
  riwayat,
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
  LatLng? _mapTarget;

  static const Map<InstansiMenu, String> _titles = {
    InstansiMenu.dashboard: 'Dashboard Operasi',
    InstansiMenu.sosAktif: 'SOS Aktif',
    InstansiMenu.laporanMasuk: 'Laporan Masuk',
    InstansiMenu.petaOperasional: 'Peta Operasional',
    InstansiMenu.riwayat: 'Riwayat',
  };

  StreamSubscription<WsMessage>? _wsSub;
  Timer? _pollingTimer;
  int _unreadSosCount = 0;
  int _unreadReportCount = 0;
  final Set<String> _readSosIds = {};
  final Set<String> _readReportIds = {};
  // Track known SOS IDs untuk deteksi incident baru dari polling (bukan hanya WS)
  final Set<String> _knownSosIds = {};

  String _agencyName = 'SIAGAKITA INSTANSI';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchUnread();
    _wsSub = widget.ws.eventStream.listen((msg) {
      if (!mounted) return;

      switch (msg.event) {
        case WsEvent.incomingEmergency:
          if (!AudioService.isPlaying) AudioService.playAlarm();
          _fetchUnread();

        // Auto-refresh: ada perubahan status insiden dari perangkat lain
        case WsEvent.incidentUpdated:
        case WsEvent.sosCancelled:
        case WsEvent.rescueAccepted:
        case WsEvent.sosStatusUpdate:
        case WsEvent.connected:
          _fetchUnread();

        // FORCE_LOGOUT: redirect ke halaman login
        case WsEvent.forceLogout:
          _pollingTimer?.cancel();
          _wsSub?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sesi Anda telah berakhir karena login di perangkat lain.',
                ),
                backgroundColor: Colors.redAccent,
                duration: Duration(seconds: 4),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }

        default:
          break;
      }
    });

    // Polling fallback: refresh setiap 30 detik jika WS sedang offline/reconecting
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (!widget.ws.isConnected) {
        _fetchUnread();
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final profile = await AgencyApiService.getProfile(widget.token);
    if (mounted && profile != null) {
      setState(() {
        _agencyName = profile['name'] as String? ?? 'SIAGAKITA INSTANSI';
      });
    }
  }

  Future<void> _fetchUnread() async {
    final incidents = await IncidentApiService.getActiveIncidents(widget.token);
    final reports = await IncidentApiService.getReports(widget.token);
    if (!mounted) return;

    // Deteksi incident baru yang belum pernah terlihat (untuk trigger alarm dari polling)
    final currentIds = incidents.map((i) => i.id).toSet();
    final newIds = currentIds.difference(_knownSosIds);
    if (newIds.isNotEmpty && _knownSosIds.isNotEmpty) {
      // Ada SOS baru masuk — play alarm jika belum playing
      if (!AudioService.isPlaying) AudioService.playAlarm();
    }
    _knownSosIds
      ..clear()
      ..addAll(currentIds);

    setState(() {
      _unreadSosCount = incidents
          .where((inc) => !_readSosIds.contains(inc.id))
          .length;
      _unreadReportCount = reports
          .where((r) =>
              (r.status == 'sent' || r.status == 'handled') &&
              !_readReportIds.contains(r.id))
          .length;
      // Alarm hanya berhenti bila semua SOS aktif sudah dibuka detail-nya
      if (_unreadSosCount == 0) AudioService.stop();
    });
  }

  /// Dipanggil saat user membuka detail sebuah SOS.
  void _onSosViewed(String id) {
    if (_readSosIds.contains(id)) return;
    setState(() {
      _readSosIds.add(id);
      _unreadSosCount = (_unreadSosCount - 1).clamp(0, 9999);
      if (_unreadSosCount == 0) AudioService.stop();
    });
  }

  /// Dipanggil saat user membuka detail sebuah laporan.
  void _onReportViewed(String id) {
    if (_readReportIds.contains(id)) return;
    setState(() {
      _readReportIds.add(id);
      _unreadReportCount = (_unreadReportCount - 1).clamp(0, 9999);
    });
  }

  void _navigateToMap(double lat, double lng) {
    setState(() {
      _mapTarget = LatLng(lat, lng);
      _activeMenu = InstansiMenu.petaOperasional;
    });
  }

  Widget _resolvePage() {
    switch (_activeMenu) {
      case InstansiMenu.dashboard:
        return DashboardOperasiPage(token: widget.token, ws: widget.ws);
      case InstansiMenu.sosAktif:
        return SosAktifPage(
          token: widget.token,
          ws: widget.ws,
          onOpenMap: _navigateToMap,
          readIds: _readSosIds,
          onSosViewed: _onSosViewed,
        );
      case InstansiMenu.laporanMasuk:
        return LaporanMasukPage(
          token: widget.token,
          onOpenMap: _navigateToMap,
          readIds: _readReportIds,
          onReportViewed: _onReportViewed,
        );
      case InstansiMenu.petaOperasional:
        return PetaOperasionalPage(
          token: widget.token,
          ws: widget.ws,
          targetLocation: _mapTarget,
        );
      case InstansiMenu.riwayat:
        return RiwayatPage(token: widget.token);
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
              unreadSosCount: _unreadSosCount,
              unreadReportCount: _unreadReportCount,
              agencyName: _agencyName,
              onSelected: (menu) {
                setState(() {
                  _activeMenu = menu;
                  if (menu != InstansiMenu.petaOperasional) {
                    _mapTarget = null;
                  }
                });
                // Alarm hanya berhenti bila semua SOS aktif dibuka detail-nya
              },
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
    required this.unreadSosCount,
    required this.unreadReportCount,
    required this.agencyName,
  });

  final InstansiMenu activeMenu;
  final ValueChanged<InstansiMenu> onSelected;
  final WsService ws;
  final int unreadSosCount;
  final int unreadReportCount;
  final String agencyName;

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  agencyName.toUpperCase(),
                  style: const TextStyle(
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
                badgeCount: unreadSosCount,
                onTap: () => onSelected(InstansiMenu.sosAktif),
              ),
              _NavItem(
                label: 'Laporan Aktif',
                icon: Icons.inbox_outlined,
                selected: activeMenu == InstansiMenu.laporanMasuk,
                badgeCount: unreadReportCount,
                onTap: () => onSelected(InstansiMenu.laporanMasuk),
              ),

              _NavItem(
                icon: Icons.map_outlined,
                label: 'Peta Operasional',
                selected: activeMenu == InstansiMenu.petaOperasional,
                onTap: () => onSelected(InstansiMenu.petaOperasional),
              ),
              _NavItem(
                icon: Icons.history_outlined,
                label: 'Riwayat',
                selected: activeMenu == InstansiMenu.riwayat,
                onTap: () => onSelected(InstansiMenu.riwayat),
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
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

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
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
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
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.account_circle,
              color: Colors.white70,
              size: 28,
            ),
            color: const Color(0xFF1E293B),
            offset: const Offset(0, 40),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Profil Saya', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Pengaturan', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Keluar', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                ws.dispose();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Menu $value segera hadir')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
