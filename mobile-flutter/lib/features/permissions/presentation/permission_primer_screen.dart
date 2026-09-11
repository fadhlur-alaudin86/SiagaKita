// Purpose:
//   Provides an interactive, contextual permission priming screen detailing
//   technical rationale for Location, Microphone, Notification, and Camera access,
//   with automatic lifecycle synchronization and soft-gating progression.
//
// Data & Logic Flow:
//   1. Queries live permission statuses on initialization and on AppLifecycleState.resumed.
//   2. Renders rationale cards with interactive grant triggers and permanent denial routing.
//   3. On continue/skip action, routes dynamically according to target (Login, MainScreen, or pop).
//
// Key Components:
//   - PermissionPrimerTarget: Destination enum for post-permission flow.
//   - PermissionPrimerScreen: Stateful UI with WidgetsBindingObserver.
//   - _PermissionCard: Interactive card widget with badge and state toggle.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/location_service.dart';
import '../../auth/login_screen.dart';
import '../../masyarakat/main_screen.dart';


enum PermissionPrimerTarget {
  login,
  mainScreen,
  returnOnly,
}


class PermissionPrimerScreen extends StatefulWidget {
  final PermissionPrimerTarget target;
  final String? accessToken;
  final String? userId;

  const PermissionPrimerScreen({
    super.key,
    required this.target,
    this.accessToken,
    this.userId,
  });

  @override
  State<PermissionPrimerScreen> createState() => _PermissionPrimerScreenState();
}


class _PermissionPrimerScreenState extends State<PermissionPrimerScreen>
    with WidgetsBindingObserver {
  bool _isLocationGranted = false;
  bool _isMicGranted = false;
  bool _isNotifGranted = false;
  bool _isCameraGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final hasLoc = await LocationService.hasPermission();
    final mic = await Permission.microphone.status;
    final notif = await Permission.notification.status;
    final cam = await Permission.camera.status;

    if (!mounted) return;
    setState(() {
      _isLocationGranted = hasLoc;
      _isMicGranted = mic.isGranted;
      _isNotifGranted = notif.isGranted;
      _isCameraGranted = cam.isGranted;
      _isLoading = false;
    });
  }

  Future<void> _handleLocationRequest() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      _showPermanentDenialDialog('Lokasi & GPS Presisi'.tr(context));
      return;
    }
    if (!mounted) return;
    await LocationService.requestPermission(context);
    await _refreshStatuses();
  }

  Future<void> _handleMicRequest() async {
    final status = await Permission.microphone.status;
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      _showPermanentDenialDialog('Akses Mikrofon'.tr(context));
      return;
    }
    await Permission.microphone.request();
    await _refreshStatuses();
  }

  Future<void> _handleNotifRequest() async {
    final status = await Permission.notification.status;
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      _showPermanentDenialDialog('Notifikasi Peringatan'.tr(context));
      return;
    }
    await Permission.notification.request();
    await _refreshStatuses();
  }

  Future<void> _handleCameraRequest() async {
    final status = await Permission.camera.status;
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      _showPermanentDenialDialog('Kamera Foto'.tr(context));
      return;
    }
    await Permission.camera.request();
    await _refreshStatuses();
  }

  void _showPermanentDenialDialog(String permissionName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162A5A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Izin Ditolak Permanen'.tr(ctx),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$permissionName: ${'Izin ini telah dinonaktifkan secara permanen. Silakan aktifkan melalui Pengaturan Aplikasi pada perangkat Anda.'.tr(ctx)}',
          style: const TextStyle(
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal'.tr(ctx),
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7418),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: Text('Buka Pengaturan'.tr(ctx)),
          ),
        ],
      ),
    );
  }

  void _navigateNext() {
    switch (widget.target) {
      case PermissionPrimerTarget.login:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        break;
      case PermissionPrimerTarget.mainScreen:
        if (widget.accessToken != null && widget.userId != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MainScreen(
                accessToken: widget.accessToken!,
                userId: widget.userId!,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        break;
      case PermissionPrimerTarget.returnOnly:
        Navigator.of(context).pop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBgColor = Color(0xFF0D1B3E);
    const Color primaryColor = Color(0xFFFF7418);

    return Scaffold(
      backgroundColor: darkBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.target == PermissionPrimerTarget.returnOnly
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          if (widget.target != PermissionPrimerTarget.returnOnly)
            TextButton(
              onPressed: _navigateNext,
              child: Text(
                'Lewati'.tr(context),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Icon
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: primaryColor.withAlpha(30),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor.withAlpha(80),
                                  width: 1.5,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.security_rounded,
                                  size: 32,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Header Title & Description
                          Center(
                            child: Text(
                              'Izin Aplikasi SiagaKita'.tr(context),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Aktifkan izin berikut untuk memastikan fitur perlindungan darurat, notifikasi evakuasi, dan pelaporan bencana berfungsi optimal.'.tr(context),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Card 1: Location (Mandatory)
                          _PermissionCard(
                            icon: Icons.location_on_rounded,
                            iconColor: const Color(0xFFFF4D4D),
                            title: 'Lokasi & GPS Presisi'.tr(context),
                            badgeText: 'Wajib'.tr(context),
                            badgeColor: const Color(0xFFFF4D4D),
                            description: 'Menentukan titik koordinat akurat saat tombol SOS ditekan agar relawan dan armada bantuan dapat segera diarahkan ke lokasi Anda.'.tr(context),
                            isGranted: _isLocationGranted,
                            onRequest: _handleLocationRequest,
                          ),
                          const SizedBox(height: 14),

                          // Card 2: Microphone (Recommended)
                          _PermissionCard(
                            icon: Icons.mic_rounded,
                            iconColor: const Color(0xFF18A3FF),
                            title: 'Akses Mikrofon'.tr(context),
                            badgeText: 'Disarankan'.tr(context),
                            badgeColor: const Color(0xFF18A3FF),
                            description: 'Merekam audio darurat secara otomatis saat sinyal SOS aktif untuk memberikan bukti situasi bahaya kepada posko siaga.'.tr(context),
                            isGranted: _isMicGranted,
                            onRequest: _handleMicRequest,
                          ),
                          const SizedBox(height: 14),

                          // Card 3: Notifications (Recommended)
                          _PermissionCard(
                            icon: Icons.notifications_active_rounded,
                            iconColor: const Color(0xFFFFB300),
                            title: 'Notifikasi Peringatan'.tr(context),
                            badgeText: 'Disarankan'.tr(context),
                            badgeColor: const Color(0xFFFFB300),
                            description: 'Menerima lansiran darurat seketika, peringatan perimeter keluarga, serta pembaruan status penanganan evakuasi.'.tr(context),
                            isGranted: _isNotifGranted,
                            onRequest: _handleNotifRequest,
                          ),
                          const SizedBox(height: 14),

                          // Card 4: Camera (Optional)
                          _PermissionCard(
                            icon: Icons.camera_alt_rounded,
                            iconColor: const Color(0xFF00C853),
                            title: 'Kamera Foto'.tr(context),
                            badgeText: 'Opsional'.tr(context),
                            badgeColor: const Color(0xFF00C853),
                            description: 'Mengambil foto bukti kejadian bencana di tempat saat Anda mengirimkan formulir pelaporan situasi darurat.'.tr(context),
                            isGranted: _isCameraGranted,
                            onRequest: _handleCameraRequest,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Area
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _navigateNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Lanjutkan ke Aplikasi'.tr(context),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (!_isLocationGranted &&
                            widget.target != PermissionPrimerTarget.returnOnly) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _navigateNext,
                            child: Text(
                              'Lewati untuk Sekarang'.tr(context),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}


class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String badgeText;
  final Color badgeColor;
  final String description;
  final bool isGranted;
  final VoidCallback onRequest;

  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.badgeText,
    required this.badgeColor,
    required this.description,
    required this.isGranted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    const Color cardBg = Color(0xFF162A5A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF00C853).withAlpha(120)
              : Colors.white12,
          width: isGranted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Title & Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: badgeColor.withAlpha(80),
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Switch / Button
              if (isGranted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00C853),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF00C853),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Aktif'.tr(context),
                        style: const TextStyle(
                          color: Color(0xFF00C853),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: onRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7418),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Aktifkan'.tr(context),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
