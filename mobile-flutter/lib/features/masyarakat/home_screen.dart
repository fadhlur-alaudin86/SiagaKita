import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_localization.dart';
import '../../core/models/user_model.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/location_service.dart';
import '../auth/login_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  final String accessToken;
  final String userId;

  const HomeScreen({
    super.key,
    required this.accessToken,
    required this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ─── SOS Tap State ──────────────────────────────────────────────────────────
  static const int _requiredTaps = 5;
  static const Duration _tapResetDuration = Duration(milliseconds: 1500);

  int _tapCount = 0;
  Timer? _tapResetTimer;

  // ─── SOS Phase State Machine ────────────────────────────────────────────────
  // idle → gracePeriod → broadcasting → (cancelled)
  String _sosPhase = 'idle'; // 'idle' | 'gracePeriod' | 'broadcasting'
  bool _isTriggeringSOS = false;

  // ─── Grace Period State ─────────────────────────────────────────────────────
  int _graceCountdown = 10;
  Timer? _graceTimer;
  String? _pendingIncidentId;

  // ─── Active SOS State ───────────────────────────────────────────────────────
  ActiveIncident? _activeIncident;
  bool _showSOSSentBanner = false;
  String? _lastTriggerMethod;
  Timer? _locationUpdateTimer;
  bool _isLoadingActiveIncident = true;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkActiveIncident();
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _graceTimer?.cancel();
    super.dispose();
  }

  // ─── Check active incident on load ──────────────────────────────────────────

  Future<void> _checkActiveIncident() async {
    setState(() => _isLoadingActiveIncident = true);
    try {
      final active = await IncidentService.getActive(
        accessToken: widget.accessToken,
      );
      if (mounted) {
        setState(() {
          _activeIncident = active;
          _isLoadingActiveIncident = false;
        });
        if (active != null) {
          _startLocationUpdates();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingActiveIncident = false);
    }
  }

  // ─── GPS Location Update (setiap 1 menit) ───────────────────────────────────

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 1), (
      _,
    ) async {
      if (_activeIncident == null || !mounted) return;
      final pos = await LocationService.getCurrentPositionOrNull();
      if (pos != null && _activeIncident != null) {
        await IncidentService.updateLocation(
          accessToken: widget.accessToken,
          incidentId: _activeIncident!.incidentId,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      }
    });
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  // ─── SOS Tap Logic (Send) ────────────────────────────────────────────────────

  void _onSOSTap() {
    // Blokir tap jika sudah ada SOS aktif, atau sedang dalam masa grace period/loading
    if (_activeIncident != null ||
        _pendingIncidentId != null ||
        _sosPhase != 'idle' ||
        _isTriggeringSOS) {
      return;
    }

    HapticFeedback.lightImpact();
    _tapResetTimer?.cancel();
    setState(() => _tapCount++);

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      HapticFeedback.heavyImpact();
      _triggerSOS(triggeredBy: 'user');
      return;
    }

    _tapResetTimer = Timer(_tapResetDuration, () {
      if (mounted) setState(() => _tapCount = 0);
    });
  }

  // ─── Cancel SOS Tap Logic (5× tap saat SOS aktif) ──────────────────────────

  void _onCancelTap() {
    HapticFeedback.lightImpact();
    _tapResetTimer?.cancel();
    setState(() => _tapCount++);

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      HapticFeedback.heavyImpact();
      _showCancelConfirmationDialog();
      return;
    }

    _tapResetTimer = Timer(_tapResetDuration, () {
      if (mounted) setState(() => _tapCount = 0);
    });
  }

  // ─── Trigger SOS ─────────────────────────────────────────────────────────────

  Future<void> _triggerSOS({required String triggeredBy}) async {
    if (_isTriggeringSOS) return;
    
    HapticFeedback.vibrate();
    setState(() {
      _tapCount = 0;
      _isTriggeringSOS = true;
    });

    final pos = await LocationService.getCurrentPositionOrNull();
    final lat = pos?.latitude ?? 0.0;
    final lng = pos?.longitude ?? 0.0;

    try {
      final result = await IncidentService.triggerSOS(
        accessToken: widget.accessToken,
        latitude: lat,
        longitude: lng,
        triggerMethod: triggeredBy,
      );

      if (!mounted) return;

      // Masuk ke fase grace period — tampilkan 4 tombol tipe
      setState(() {
        _pendingIncidentId = result.incidentId;
        _sosPhase = 'gracePeriod';
        _graceCountdown = 10;
        _isTriggeringSOS = false;
      });
      _startGracePeriodCountdown();
    } on SOSBannedException catch (e) {
      if (!mounted) return;
      setState(() => _isTriggeringSOS = false);
      _showSOSBannedDialog(e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTriggeringSOS = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim SOS: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // ─── Grace Period: countdown & pilih tipe ────────────────────────────────────

  void _startGracePeriodCountdown() {
    _graceTimer?.cancel();
    _graceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _graceCountdown--);
      HapticFeedback.selectionClick();
      if (_graceCountdown <= 0) {
        timer.cancel();
        _onGraceTimeout();
      }
    });
  }

  Future<void> _onSelectIncidentType(String type) async {
    _graceTimer?.cancel();
    if (_pendingIncidentId == null) return;
    try {
      await IncidentService.updateType(
        accessToken: widget.accessToken,
        incidentId: _pendingIncidentId!,
        incidentType: type,
      );
    } catch (_) {
      /* silent */
    }
    _transitionToBroadcasting();
  }

  Future<void> _onGraceTimeout() async {
    if (_pendingIncidentId == null) return;
    await IncidentService.broadcast(
      accessToken: widget.accessToken,
      incidentId: _pendingIncidentId!,
    );
    _transitionToBroadcasting();
  }

  void _transitionToBroadcasting() {
    if (!mounted) return;
    final newIncident = ActiveIncident(
      incidentId: _pendingIncidentId!,
      status: 'broadcasting',
      incidentType: 'unknown',
      latitude: 0,
      longitude: 0,
      createdAt: DateTime.now().toIso8601String(),
    );
    setState(() {
      _activeIncident = newIncident;
      _pendingIncidentId = null;
      _sosPhase = 'broadcasting';
      _showSOSSentBanner = true;
    });
    _startLocationUpdates();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showSOSSentBanner = false);
    });
  }

  void _showSOSBannedDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('SOS Dinonaktifkan'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ─── Cancel Active SOS ───────────────────────────────────────────────────────

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan SOS?'),
        content: const Text(
          'Apakah Anda yakin situasi sudah aman dan ingin membatalkan laporan SOS ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TIDAK', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeCancelSOS();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('YA, BATALKAN'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCancelSOS() async {
    setState(() {
      _tapCount = 0;
    });

    if (_activeIncident == null) return;

    try {
      await IncidentService.cancelSOS(
        accessToken: widget.accessToken,
        incidentId: _activeIncident!.incidentId,
      );
      if (!mounted) return;
      _stopLocationUpdates();
      setState(() {
        _activeIncident = null;
        _sosPhase = 'idle';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('SOS berhasil dibatalkan.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan SOS: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primaryColor = Theme.of(context).primaryColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSOSActive = _activeIncident != null;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      ValueListenableBuilder<UserModel>(
                        valueListenable: UserModel.currentUser,
                        builder: (context, user, child) {
                          return Column(
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(
                                  color: isSOSActive
                                      ? Colors.red
                                      : primaryColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isSOSActive
                                          ? Colors.red
                                          : Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isSOSActive ? 'SOS AKTIF' : 'Online',
                                    style: TextStyle(
                                      color: isSOSActive ? Colors.red : Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${user.roleLabel}',
                                    style: TextStyle(
                                      color: colors.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isSOSActive
                                    ? 'SOS AKTIF — Ketuk 5× untuk batalkan'
                                    : 'Ketuk 5× untuk mengirim SOS'.tr(context),
                                style: TextStyle(
                                  color: isSOSActive
                                      ? Colors.red.withValues(alpha: 0.8)
                                      : colors.onSurface.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontWeight: isSOSActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      GestureDetector(
                        onTap: () => _showProfileMenu(context, UserModel.currentUser.value, isDarkMode),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3), 
                              width: 2,
                            ),
                            boxShadow: isDarkMode
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                          ),
                          child: Icon(
                            Icons.person,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Active SOS status banner ─────────────────────────────────
                  if (isSOSActive && !_isLoadingActiveIncident) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emergency_share,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'SOS AKTIF — Lokasi diperbarui tiap 1 menit',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // ── SOS Button ────────────────────────────────────────────────
                  Column(
                    children: [
                      GestureDetector(
                        onTap: isSOSActive ? _onCancelTap : _onSOSTap,
                        child: SizedBox(
                          width: 250,
                          height: 250,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer progress ring (tap count)
                              if (_tapCount > 0)
                                SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: CircularProgressIndicator(
                                    value: _tapCount / _requiredTaps,
                                    strokeWidth: 8,
                                    backgroundColor:
                                        (isSOSActive
                                                ? Colors.red
                                                : primaryColor)
                                            .withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isSOSActive
                                          ? Colors.red
                                          : Colors.orangeAccent,
                                    ),
                                  ),
                                ),
                              // Main SOS / Cancel Button
                              AnimatedScale(
                                scale: _tapCount > 0 ? 0.96 : 1.0,
                                duration: const Duration(milliseconds: 80),
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: isSOSActive
                                          ? [
                                              Colors.red,
                                              const Color(0xFF8B0000),
                                            ]
                                          : [
                                              primaryColor,
                                              const Color(0xFFCB5100),
                                            ],
                                    ),
                                    border: Border.all(
                                      color: (_tapCount > 0
                                          ? (isSOSActive
                                                ? Colors.red
                                                : const Color(0xFFFFA265))
                                          : (isDarkMode
                                                ? Colors.white.withValues(
                                                    alpha: 0.2,
                                                  )
                                                : (isSOSActive
                                                          ? Colors.red
                                                          : primaryColor)
                                                      .withValues(alpha: 0.3))),
                                      width: 8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (isSOSActive
                                                    ? Colors.red
                                                    : primaryColor)
                                                .withValues(
                                                  alpha: _tapCount > 0
                                                      ? 0.8
                                                      : (isDarkMode
                                                            ? 0.3
                                                            : 0.6),
                                                ),
                                        blurRadius: _tapCount > 0 ? 50 : 30,
                                        spreadRadius: _tapCount > 0
                                            ? 10
                                            : (isDarkMode ? 5 : 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isSOSActive
                                            ? Icons.cancel_outlined
                                            : Icons.error_outline,
                                        color: Colors.white,
                                        size: 60,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        isSOSActive ? 'AKTIF' : 'SOS',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        isSOSActive
                                            ? 'KETUK 5× BATALKAN'
                                            : 'KETUK 5×'.tr(context),
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tap count indicator dots
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_requiredTaps, (i) {
                          final filled = i < _tapCount;
                          final dotColor = isSOSActive
                              ? Colors.red
                              : primaryColor;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: filled ? 14 : 10,
                            height: filled ? 14 : 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? dotColor
                                  : colors.onSurface.withValues(alpha: 0.2),
                              boxShadow: filled
                                  ? [
                                      BoxShadow(
                                        color: dotColor.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : [],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      AnimatedOpacity(
                        opacity: _tapCount > 0 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          '$_tapCount/$_requiredTaps',
                          style: TextStyle(
                            color: isSOSActive ? Colors.red : primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Bottom Action Cards ────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportScreen(
                                  accessToken: widget.accessToken,
                                ),
                              ),
                            );
                          },
                          child: _actionCard(
                            colors: colors,
                            isDarkMode: isDarkMode,
                            icon: Icons.description_outlined,
                            iconColor: colors.secondary,
                            title: 'Laporkan'.tr(context),
                            subtitle: 'Kirim bukti & titik\nlokasi'.tr(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _actionCard(
                          colors: colors,
                          isDarkMode: isDarkMode,
                          icon: Icons.menu_book_outlined,
                          iconColor: primaryColor,
                          title: 'Edukasi'.tr(context),
                          subtitle: 'Panduan\npenyelamatan'.tr(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Grace Period Overlay (pilih tipe insiden) ──────────────────
            if (_sosPhase == 'gracePeriod') _buildGracePeriodOverlay(colors),

            // ── SOS Sent Banner ────────────────────────────────────────────────
            if (_showSOSSentBanner)
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: -60, end: 0),
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, value),
                    child: child!,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7418),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7418).withValues(alpha: 0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SINYAL SOS TERKIRIM!'.tr(context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bantuan sedang diarahkan ke lokasi Anda.'.tr(
                            context,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_lastTriggerMethod == 'timeout') ...[
                          const SizedBox(height: 4),
                          const Text(
                            '(Terkirim otomatis — konfirmasi habis)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Action Card helper ────────────────────────────────────────────────────

  Widget _actionCard({
    required ColorScheme colors,
    required bool isDarkMode,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Confirmation Dialog ────────────────────────────────────────────────────

  // ─── Profile Menu ──────────────────────────────────────────────────────────

  void _showProfileMenu(BuildContext context, UserModel user, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(user.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profil Saya'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(accessToken: widget.accessToken)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Pengaturan'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Keluar Aplikasi', style: TextStyle(color: Colors.red)),
                onTap: () {
                  UserModel.currentUser.value = const UserModel(id: '', name: '', email: '', role: UserRole.masyarakat);
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ─── Grace Period Overlay ─────────────────────────────────────────────────────

  Widget _buildGracePeriodOverlay(ColorScheme colors) {
    final types = [
      {'label': 'KEBAKARAN', 'icon': '🔥', 'value': 'fire'},
      {'label': 'MEDIS', 'icon': '🚑', 'value': 'medical'},
      {'label': 'KRIMINAL', 'icon': '🔪', 'value': 'crime'},
      {'label': 'KECELAKAAN', 'icon': '💥', 'value': 'rescue'},
    ];

    return Container(
      color: const Color(0xFFCC0000),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '🆘 SOS DIKIRIM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih jenis darurat (opsional)',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tidak memilih pun tidak apa-apa — bantuan tetap datang',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 32),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: types.map((t) {
                  return GestureDetector(
                    onTap: () => _onSelectIncidentType(t['value']!),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t['icon']!,
                            style: const TextStyle(fontSize: 36),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t['label']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _graceCountdown / 10,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_graceCountdown detik',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _graceTimer?.cancel();
                    IncidentService.cancelSOS(
                      accessToken: widget.accessToken,
                      incidentId: _pendingIncidentId!,
                    );
                    setState(() {
                      _sosPhase = 'idle';
                      _pendingIncidentId = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'BATALKAN SOS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
