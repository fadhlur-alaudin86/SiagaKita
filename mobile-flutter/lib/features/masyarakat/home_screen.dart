import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../core/localization/app_localization.dart';
import '../../core/models/user_model.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/location_service.dart';
import 'report_screen.dart';
import 'guide_screen.dart';

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
  // Status upload SOS ke server
  // 'idle' | 'sending' | 'sent' | 'failed'
  String _sosUploadStatus = 'idle';
  Timer? _sosRetryTimer;

  // ─── Grace Period State ─────────────────────────────────────────────────────
  int _graceCountdown = 10;
  Timer? _graceTimer;
  String? _pendingIncidentId;

  // ─── Active SOS State ───────────────────────────────────────────────────────
  ActiveIncident? _activeIncident;
  bool _showSOSSentBanner = false;
  String? _lastTriggerMethod;
  Timer? _locationUpdateTimer;
  Timer? _statusCheckTimer; // polling cepat (10 detik) khusus saat SOS aktif
  bool _isLoadingActiveIncident = true;

  // Untuk menyimpan ID insiden lokal jika user membatalkan saat proses upload masih berlangsung
  String? _cancelledLocalId;

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
    _statusCheckTimer?.cancel();
    _graceTimer?.cancel();
    _sosRetryTimer?.cancel();
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

      // 1. Cek apakah SOS masih aktif di server (mungkin diselesaikan oleh agency)
      try {
        final active = await IncidentService.getActive(
          accessToken: widget.accessToken,
        );
        if (!mounted) return;
        if (active == null) {
          _stopLocationUpdates();
          setState(() => _activeIncident = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status SOS telah diselesaikan oleh instansi.'),
              backgroundColor: Colors.green,
            ),
          );
          return;
        }
      } catch (_) {
        // Jika error jaringan, biarkan saja (jangan reset UI)
      }

      // 2. Jika masih aktif, update lokasi GPS ke server
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
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
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

  // ─── Trigger SOS — INSTANT GRACE PERIOD + background upload & retry ──────────

  Future<void> _triggerSOS({required String triggeredBy}) async {
    if (_isTriggeringSOS) return;

    HapticFeedback.vibrate();

    // Buat ID lokal sementara (UUID). Tidak ditampilkan ke UI.
    final localId = const Uuid().v4();

    setState(() {
      _tapCount = 0;
      _isTriggeringSOS = true;
      // Langsung masuk grace period — tidak menunggu server
      _pendingIncidentId = localId;
      _sosPhase = 'gracePeriod';
      _graceCountdown = 10;
      _sosUploadStatus = 'sending';
    });
    _startGracePeriodCountdown();

    // Ambil posisi GPS di background
    double lat = 0.0;
    double lng = 0.0;
    try {
      final pos = await LocationService.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } on AppLocationServiceDisabledException {
      _cancelGracePeriodLocally();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Gagal mengirim SOS: GPS perangkat Anda dimatikan.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
        Geolocator.openLocationSettings();
      }
      if (mounted) setState(() => _isTriggeringSOS = false);
      return;
    } on AppLocationPermissionException {
      _cancelGracePeriodLocally();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Gagal mengirim SOS: Izin akses lokasi belum diberikan.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
        LocationService.requestPermission(context);
      }
      if (mounted) setState(() => _isTriggeringSOS = false);
      return;
    } catch (_) {
      _cancelGracePeriodLocally();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Gagal mengirim SOS: Tidak dapat mengambil lokasi Anda.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      if (mounted) setState(() => _isTriggeringSOS = false);
      return;
    }

    // Upload SOS di background — retry tiap 5 detik jika gagal
    _attemptSOSUpload(
      lat: lat,
      lng: lng,
      triggeredBy: triggeredBy,
      localId: localId,
    );

    if (mounted) setState(() => _isTriggeringSOS = false);
  }

  /// Kirim SOS ke server. Jika gagal, ulangi tiap 5 detik.
  void _attemptSOSUpload({
    required double lat,
    required double lng,
    required String triggeredBy,
    required String localId,
  }) {
    _sosRetryTimer?.cancel();
    _performSOSUpload(
      lat: lat,
      lng: lng,
      triggeredBy: triggeredBy,
      localId: localId,
    );
  }

  Future<void> _performSOSUpload({
    required double lat,
    required double lng,
    required String triggeredBy,
    required String localId,
  }) async {
    // Hentikan jika sudah tidak relevan (dibatalkan user / sudah ada server ID)
    if (!mounted) return;
    if (_sosPhase == 'idle') return;
    if (_pendingIncidentId != null && _pendingIncidentId != localId) return;

    try {
      final result = await IncidentService.triggerSOS(
        accessToken: widget.accessToken,
        latitude: lat,
        longitude: lng,
        triggerMethod: triggeredBy,
      );

      if (!mounted) return;

      final bool wasCancelled = _cancelledLocalId == localId;

      // Ganti local ID dengan server ID (tidak tampil di UI)
      setState(() {
        if (_pendingIncidentId == localId) {
          _pendingIncidentId = result.incidentId;
        }
        _sosUploadStatus = 'sent';
        if (_activeIncident != null && _activeIncident!.incidentId == localId) {
          _activeIncident = ActiveIncident(
            incidentId: result.incidentId,
            status: _activeIncident!.status,
            incidentType: _activeIncident!.incidentType,
            latitude: _activeIncident!.latitude,
            longitude: _activeIncident!.longitude,
            createdAt: _activeIncident!.createdAt,
            reporterTrustLabel: _activeIncident!.reporterTrustLabel,
          );
        }
      });

      if (wasCancelled) {
        IncidentService.cancelSOS(
          accessToken: widget.accessToken,
          incidentId: result.incidentId,
        ).catchError((_) {}); // silent background cancel
        _cancelledLocalId = null;
      }
    } on SOSBannedException catch (e) {
      if (!mounted) return;
      // SOS banned → batalkan grace period
      _cancelGracePeriodLocally();
      _showSOSBannedDialog(e.toString());
    } catch (_) {
      if (!mounted) return;
      setState(() => _sosUploadStatus = 'sending');
      // Retry setiap 5 detik selama phase masih aktif
      _sosRetryTimer = Timer(const Duration(seconds: 5), () {
        _performSOSUpload(
          lat: lat,
          lng: lng,
          triggeredBy: triggeredBy,
          localId: localId,
        );
      });
    }
  }

  /// Batalkan grace period secara lokal (karena SOS banned atau error kritis).
  void _cancelGracePeriodLocally() {
    _graceTimer?.cancel();
    _sosRetryTimer?.cancel();
    setState(() {
      _sosPhase = 'idle';
      _pendingIncidentId = null;
      _isTriggeringSOS = false;
      _sosUploadStatus = 'idle';
      _graceCountdown = 10;
    });
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
    _startStatusPolling(); // start fast polling setelah SOS aktif
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showSOSSentBanner = false);
    });
  }

  // ─── Fast Status Polling (setiap 10 detik saat SOS aktif) ─────────────────

  void _startStatusPolling() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || _activeIncident == null) return;
      try {
        final active = await IncidentService.getActive(
          accessToken: widget.accessToken,
        );
        if (!mounted) return;
        if (active == null) {
          _stopLocationUpdates();
          setState(() {
            _activeIncident = null;
            _sosPhase = 'idle';
            _sosUploadStatus = 'idle';
            _tapCount = 0;
            _cancelledLocalId = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Status SOS telah diselesaikan oleh instansi.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (_) {
        // Jika error jaringan, biarkan (jangan reset UI)
      }
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

  /// Badge kecil yang menampilkan status upload SOS ke server.
  Widget _buildUploadStatusBadge() {
    if (_sosUploadStatus == 'idle') return const SizedBox.shrink();
    final isSent = _sosUploadStatus == 'sent';
    final text = isSent ? 'Terkirim ✓' : 'Mengirim...';
    final color = isSent ? Colors.green : Colors.orange;
    final icon = isSent ? Icons.check_circle_outline : Icons.sync;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
    setState(() => _tapCount = 0);

    // Hentikan retry loop jika masih berjalan
    _sosRetryTimer?.cancel();

    if (_activeIncident == null) return;

    final targetId = _activeIncident!.incidentId;

    if (_sosUploadStatus == 'sending') {
      _cancelledLocalId = targetId;
    } else {
      try {
        await IncidentService.cancelSOS(
          accessToken: widget.accessToken,
          incidentId: targetId,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan SOS: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return; // jangan clear state jika gagal di server (biar bisa dicoba lagi)
      }
    }

    if (!mounted) return;
    _stopLocationUpdates();
    setState(() {
      _activeIncident = null;
      _sosPhase = 'idle';
      _sosUploadStatus = 'idle';
      _tapCount = 0;
      _cancelledLocalId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('SOS berhasil dibatalkan.'),
        backgroundColor: Colors.green.shade700,
      ),
    );
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
                      const SizedBox(
                        width: 40,
                      ), // placeholder to balance header
                      Expanded(
                        child: ValueListenableBuilder<UserModel>(
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
                                const SizedBox(height: 4),
                                ValueListenableBuilder<bool>(
                                  valueListenable: ConnectivityService.isOnline,
                                  builder: (_, online, child) {
                                    final statusText = isSOSActive
                                        ? 'SOS AKTIF'
                                        : online
                                        ? 'Online'
                                        : 'Offline';
                                    final statusColor = isSOSActive
                                        ? Colors.red
                                        : online
                                        ? Colors.green
                                        : Colors.grey;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                            color: colors.onSurface.withValues(
                                              alpha: 0.6,
                                            ),
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
                                      ? 'SOS AKTIF — Ketuk 5× untuk batalkan'
                                      : 'Ketuk 5× untuk mengirim SOS'.tr(
                                          context,
                                        ),
                                  style: TextStyle(
                                    color: isSOSActive
                                        ? Colors.red.withValues(alpha: 0.8)
                                        : colors.onSurface.withValues(
                                            alpha: 0.6,
                                          ),
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
                      ),
                      const SizedBox(
                        width: 40,
                      ), // placeholder to balance header
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
                              ),
                            ),
                          ),
                          // Badge status upload
                          _buildUploadStatusBadge(),
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
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GuideScreen(),
                            ),
                          ),
                          child: _actionCard(
                            colors: colors,
                            isDarkMode: isDarkMode,
                            icon: Icons.menu_book_outlined,
                            iconColor: primaryColor,
                            title: 'Edukasi'.tr(context),
                            subtitle: 'Panduan\npenyelamatan'.tr(context),
                          ),
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

  // ─── Grace Period Overlay ─────────────────────────────────────────────────────

  Widget _buildGracePeriodOverlay(ColorScheme colors) {
    final types = [
      {'label': 'KEBAKARAN', 'icon': '🔥', 'value': 'fire'},
      {'label': 'MEDIS', 'icon': '🚑', 'value': 'medical'},
      {'label': 'KRIMINAL', 'icon': '🔪', 'value': 'crime'},
      {'label': 'KECELAKAAN', 'icon': '💥', 'value': 'rescue'},
      {'label': 'BENCANA ALAM', 'icon': '🌪️', 'value': 'disaster'},
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
              const Spacer(),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                physics: const NeverScrollableScrollPhysics(),
                children: types.map((t) {
                  return GestureDetector(
                    onTap: () =>
                        _showTypeConfirmDialog(t['label']!, t['value']!),
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
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t['label']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _graceTimer?.cancel();

                    if (_sosUploadStatus == 'sending') {
                      _cancelledLocalId = _pendingIncidentId;
                    } else {
                      IncidentService.cancelSOS(
                        accessToken: widget.accessToken,
                        incidentId: _pendingIncidentId!,
                      ).catchError((_) {});
                    }

                    setState(() {
                      _sosPhase = 'idle';
                      _pendingIncidentId = null;
                      _isTriggeringSOS = false;
                      _sosUploadStatus = 'idle';
                      _graceCountdown = 10;
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

  void _showTypeConfirmDialog(String label, String value) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF990000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Konfirmasi Tipe Darurat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Anda memilih: $label\n\nApakah ini jenis darurat yang tepat?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TIDAK', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _onSelectIncidentType(value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFCC0000),
            ),
            child: const Text(
              'YA, LANJUTKAN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
