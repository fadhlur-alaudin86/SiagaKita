import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../core/localization/app_localization.dart';
import '../../core/utils/responsive.dart';
import '../../core/models/user_model.dart';
import '../../core/services/background_service.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/location_controller.dart';
import '../../core/services/location_service.dart';
import '../../core/services/mobile_ws_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/offline_service.dart';
import '../../core/services/connectivity_service.dart';
import 'report_screen.dart';
import 'widgets/home_widgets.dart';
import 'widgets/sos_active_widgets.dart';

class HomeScreen extends StatefulWidget {
  final String accessToken;
  final String userId;
  final bool isSOSBanned;

  const HomeScreen({
    super.key,
    required this.accessToken,
    required this.userId,
    this.isSOSBanned = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ─── SOS Tap State ──────────────────────────────────────────────────────────
  static const int _requiredTaps = 3;
  static const Duration _tapResetDuration = Duration(milliseconds: 1500);

  int _tapCount = 0;
  Timer? _tapResetTimer;

  // ─── SOS Phase State Machine ────────────────────────────────────────────────
  // idle → gracePeriod → broadcasting → (canceled)
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
  Timer? _locationUpdateTimer;
  Timer? _statusCheckTimer; // polling cepat (10 detik) khusus saat SOS aktif
  bool _isLoadingActiveIncident = true;

  // ─── Telemetri SOS (Tahap 4) ──────────────────────────────────────────────────
  int _nextUpdateCountdown =
      3; // hitung mundur update lokasi berikutnya (detik)

  DateTime? _lastLocationUpdate; // timestamp lokasi terakhir berhasil diupdate
  bool _sosTransmitting =
      false; // apakah koneksi SOS dalam keadaan baik (mulai false sampai ada HTTP sukses)
  Timer? _countdownTimer; // hitung mundur 1 detik

  // Untuk menyimpan ID insiden lokal jika user membatalkan saat proses upload masih berlangsung
  String? _cancelledLocalId;

  // ─── Lokasi Relawan (Poin 4) ─────────────────────────────────────────────────
  // Posisi terkini relawan yang sedang menangani SOS ini (dari WS)
  ({double lat, double lng, String? address, String? updatedAt})?
  _volunteerPosition;

  // ─── SOS Cooldown (1 menit setelah SOS selesai) ────────────────────────────
  int _sosCooldownSeconds = 0;
  Timer? _sosCooldownTimer;

  // ─── Heartbeat Ping ──────────────────────────────────────────────────────────
  Timer? _pingTimer;

  // ─── WebSocket & Vibration ───────────────────────────────────────────────────
  MobileWsService? _ws;
  StreamSubscription<MobileWsMessage>? _wsSub;
  Timer? _vibrationTimer;
  bool _vibrating = false;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkActiveIncident();
    // Shared location controller
    // LocationController.instance.start(); // Legacy
    // Heartbeat ping setiap 30 detik
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      UserService.ping(widget.accessToken);
    });
    UserService.ping(widget.accessToken);
    // WebSocket real-time
    _ws = MobileWsService(token: widget.accessToken);
    _ws!.connect();
    _wsSub = _ws!.eventStream.listen(_onWsEvent);
    LocationController.instance.addListener(_handlePositionChange);
  }

  void _onWsEvent(MobileWsMessage msg) {
    if (!mounted) return;
    switch (msg.event) {
      case MobileWsEvent.agencyHandling:
        _onHandlerArrived(byAgency: true);
        break;
      case MobileWsEvent.volunteerHandling:
        _onHandlerArrived(byAgency: false);
        break;
      case MobileWsEvent.volunteerLocationUpdate:
        // Simpan posisi relawan dari payload WS
        final p = msg.payload;
        final lat = (p['latitude'] as num?)?.toDouble();
        final lng = (p['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null && mounted) {
          setState(() {
            _volunteerPosition = (
              lat: lat,
              lng: lng,
              address: p['address_detail'] as String?,
              updatedAt: p['updated_at'] as String?,
            );
          });
        }
        break;
      case MobileWsEvent.reporterLocationUpdate:
        // Di HomeScreen (Masyarakat), kita adalah reporter.
        // Update ini biasanya untuk relawan/instansi.
        break;
      case MobileWsEvent.sosResolved:
        _stopVibration();
        _stopLocationUpdates();
        setState(() {
          _activeIncident = null;
          _sosPhase = 'idle';
          _sosUploadStatus = 'idle';
          _tapCount = 0;
          _volunteerPosition = null;
        });
        // Sync ke global state
        UserModel.currentUser.value = UserModel.currentUser.value.copyWith(
          isSOSActive: false,
        );
        _startCooldown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'SOS Anda telah diselesaikan. Terima kasih!'.tr(context),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        break;
      case MobileWsEvent.forceLogout:
        _handleForceLogout();
        break;
      case MobileWsEvent.sosCancelled:
      case MobileWsEvent.connected:
      case MobileWsEvent.unknown:
        break;
    }

    // Refresh status dari server setelah event WS
    if (_activeIncident != null) {
      _checkHandlerStatus();
    }
  }

  void _handleForceLogout() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sesi Anda telah berakhir karena login di perangkat lain.'.tr(
            context,
          ),
        ),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 4),
      ),
    );
    // Logout dan redirect ke login
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  /// Dipanggil saat ada instansi atau relawan yang mulai handle.
  void _onHandlerArrived({required bool byAgency}) {
    _stopVibration();
    Vibration.vibrate(duration: 800); // konfirmasi 1x getaran panjang
    _checkHandlerStatus(); // refresh status
    if (!mounted) return;
    final msg = byAgency
        ? 'Badan Penyelamat sedang dalam perjalanan ke lokasi Anda!'.tr(context)
        : 'Relawan sedang menuju lokasi Anda!'.tr(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Polling status penangan dari server (dipanggil setelah event WS).
  Future<void> _checkHandlerStatus() async {
    try {
      final active = await IncidentService.getActive(
        accessToken: widget.accessToken,
      );
      if (!mounted) return;
      if (active == null) {
        _stopVibration();
        _stopLocationUpdates();
        setState(() {
          _activeIncident = null;
          _sosPhase = 'idle';
          _sosUploadStatus = 'idle';
          _tapCount = 0;
        });
      } else {
        setState(() => _activeIncident = active);
        if (active.isBeingHandled) {
          _stopVibration();
        }
      }
    } catch (_) {}
  }

  // ─── Vibration ───────────────────────────────────────────────────────────────

  void _startVibration() {
    if (_vibrating) return;
    _vibrating = true;
    // Foreground vibration
    _doVibrate();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_vibrating && mounted) _doVibrate();
    });
    // Background vibration (via Service)
    FlutterBackgroundService().invoke('startVibration');
  }

  void _doVibrate() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 150, 100, 150]);
    }
  }

  void _stopVibration() {
    _vibrating = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    Vibration.cancel();
    // Stop background vibration
    FlutterBackgroundService().invoke('stopVibration');
  }

  // ─── SOS Cooldown ─────────────────────────────────────────────────────────

  void _startCooldown() {
    _sosCooldownTimer?.cancel();
    setState(() => _sosCooldownSeconds = 60);
    _sosCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _sosCooldownSeconds--);
      if (_sosCooldownSeconds <= 0) {
        _sosCooldownTimer?.cancel();
        _sosCooldownTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _tapResetTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _statusCheckTimer?.cancel();
    _graceTimer?.cancel();
    _sosRetryTimer?.cancel();
    _countdownTimer?.cancel();
    _vibrationTimer?.cancel();
    _sosCooldownTimer?.cancel();
    _wsSub?.cancel();
    if (_ws != null) {
      _ws!.dispose();
    }
    LocationController.instance.removeListener(_handlePositionChange);
    // Lepaskan semua GPS caller dari HomeScreen
    LocationController.instance.releaseMode('home_screen_sos');
    super.dispose();
  }

  // ─── Check active incident on load ──────────────────────────────────────────

  Future<void> _checkActiveIncident() async {
    setState(() => _isLoadingActiveIncident = true);

    // Cek apakah ada SOS pending di offline cache (sebelum hit API)
    final pendingSos = await OfflineService.getPendingSOS();
    if (pendingSos != null) {
      final localId = pendingSos['local_id'] as String;
      final lat = pendingSos['latitude'] as double;
      final lng = pendingSos['longitude'] as double;
      final address = pendingSos['address_detail'] as String?;

      setState(() {
        _pendingIncidentId = localId;
        _sosPhase =
            'gracePeriod'; // Atau broadcasting tergantung waktu, tapi untuk simplifikasi kita mulai ulang proses upload
        _sosUploadStatus = 'sending';
      });

      // Lanjutkan background upload
      _attemptSOSUpload(
        lat: lat,
        lng: lng,
        addressDetail: address,
        triggeredBy: 'user',
        localId: localId,
      );
    }

    // Cek apakah ada cancel SOS pending
    final pendingCancel = await OfflineService.getPendingCancelSOS();
    if (pendingCancel != null) {
      _attemptSOSCancelBackground(pendingCancel);
    }

    try {
      final active = await IncidentService.getActive(
        accessToken: widget.accessToken,
      );
      if (mounted) {
        setState(() {
          _activeIncident = active;
          _isLoadingActiveIncident = false;
          // Jika ada active dari server, berari pending offline sudah sinkron atau tidak relevan
          if (active != null && pendingSos != null) {
            OfflineService.clearPendingSOS();
            _pendingIncidentId = null;
            _sosPhase = 'idle'; // Nanti ditimpa kalau server bilang dia aktif
          }
        });
        if (active != null) {
          _startLocationUpdates();
          _startStatusPolling();
          if (!active.isBeingHandled) _startVibration();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingActiveIncident = false);
    }
  }

  // ─── GPS Location Update (setiap 10 detik) ───────────────────────────────────

  void _startLocationUpdates() {
    _startCountdownTimer();

    // Daftarkan GPS mode active dengan caller ID khusus SOS
    LocationController.instance.requestMode(
      'home_screen_sos',
      TrackingMode.active,
    );

    // Beritahu background service untuk mulai mengirim lokasi (saat app di-background)
    final incidentId = _activeIncident?.incidentId ?? _pendingIncidentId ?? '';
    if (incidentId.isNotEmpty) {
      AppBackgroundService.startSOSTracking(incidentId);
    }
  }

  void _stopLocationUpdates() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    // Lepaskan GPS dari SOS caller
    LocationController.instance.releaseMode('home_screen_sos');
    // Beritahu background service agar berhenti mengirim lokasi SOS
    AppBackgroundService.stopSOSTracking();
  }

  Future<void> _handlePositionChange() async {
    final pos = LocationController.instance.currentPosition;
    if (pos == null || _activeIncident == null || !mounted) return;

    // 1. Kirim lokasi terbaru via WebSocket (Real-time)
    _ws?.sendLocation(pos.lat, pos.lng);

    // 2. Fallback: Update di DB via HTTP setiap 3 detik saat SOS aktif
    final now = DateTime.now();
    if (_lastLocationUpdate == null ||
        now.difference(_lastLocationUpdate!) > const Duration(seconds: 3)) {
      try {
        await IncidentService.updateLocation(
          accessToken: widget.accessToken,
          incidentId: _activeIncident!.incidentId,
          latitude: pos.lat,
          longitude: pos.lng,
        );
        if (mounted) {
          setState(() {
            _lastLocationUpdate = now;
            _sosTransmitting = true;
            _nextUpdateCountdown = 3;
            // Jangan set _sosUploadStatus di sini — hanya dari polling status
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _sosTransmitting = false;
          });
        }
      }
    }
  }

  /// Countdown timer 1 detik untuk menampilkan hitung mundur update lokasi.
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _activeIncident == null) return;
      setState(() {
        if (_nextUpdateCountdown > 0) {
          _nextUpdateCountdown--;
        }
      });
    });
  }

  // ─── SOS Tap Logic (Send) ────────────────────────────────────────────────────

  void _onSOSTap() {
    // Blokir jika akun di-ban
    if (widget.isSOSBanned) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akun Anda diblokir dari fitur SOS. Hubungi admin.'.tr(context),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    // Blokir tap jika dalam masa cooldown
    if (_sosCooldownSeconds > 0) return;
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

  // ─── Trigger SOS - INSTANT GRACE PERIOD + background upload & retry ──────────

  Future<void> _triggerSOS({required String triggeredBy}) async {
    if (_isTriggeringSOS) return;

    HapticFeedback.vibrate();

    // Buat ID lokal sementara (UUID). Tidak ditampilkan ke UI.
    final localId = const Uuid().v4();

    setState(() {
      _tapCount = 0;
      _isTriggeringSOS = true;
      // Langsung masuk grace period - tidak menunggu server
      _pendingIncidentId = localId;
      _sosPhase = 'gracePeriod';
      _graceCountdown = 10;
      _sosUploadStatus = 'sending';
    });
    _startGracePeriodCountdown();

    // Constraint 2: Set global SOS status and turn off duty
    final currentUser = UserModel.currentUser.value;
    UserModel.currentUser.value = currentUser.copyWith(
      isSOSActive: true,
      isAvailableForMission: false,
    );

    // Kirim update availability ke server (background)
    if (currentUser.isAvailableForMission) {
      UserService.updateAvailability(
        widget.accessToken,
        false,
      ).catchError((_) {});
    }

    // Ambil posisi GPS di background
    double lat = 0.0;
    double lng = 0.0;
    String? address;
    try {
      final pos = await LocationService.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
      // Reverse geocoding (best effort, maksimal 2 detik)
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18',
        );
        final res = await http
            .get(uri, headers: {'User-Agent': 'com.siagakita.mobile'})
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final display = data['display_name'] as String?;
          if (display != null) {
            final parts = display.split(', ');
            address = parts.take(3).join(', ');
          }
        }
      } catch (_) {
        // Abaikan jika geocoding gagal/timeout
      }
    } on AppLocationServiceDisabledException {
      _cancelGracePeriodLocally();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengirim SOS: GPS perangkat Anda dimatikan.'.tr(context),
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
            content: Text(
              'Gagal mengirim SOS: Izin akses lokasi belum diberikan.'.tr(
                context,
              ),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      if (mounted) setState(() => _isTriggeringSOS = false);
      return;
    } catch (_) {
      _cancelGracePeriodLocally();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengirim SOS: Tidak dapat mengambil lokasi Anda.'.tr(
                context,
              ),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      if (mounted) setState(() => _isTriggeringSOS = false);
      return;
    }

    // Simpan status pending SOS ke SharedPreferences
    OfflineService.savePendingSOS(
      localId: localId,
      lat: lat,
      lng: lng,
      addressDetail: address,
    );

    // Upload SOS di background - retry tiap 5 detik jika gagal
    _attemptSOSUpload(
      lat: lat,
      lng: lng,
      addressDetail: address,
      triggeredBy: triggeredBy,
      localId: localId,
    );

    if (mounted) setState(() => _isTriggeringSOS = false);
  }

  /// Kirim SOS ke server. Jika gagal, ulangi tiap 5 detik.
  void _attemptSOSUpload({
    required double lat,
    required double lng,
    String? addressDetail,
    required String triggeredBy,
    required String localId,
  }) {
    _sosRetryTimer?.cancel();
    _performSOSUpload(
      lat: lat,
      lng: lng,
      addressDetail: addressDetail,
      triggeredBy: triggeredBy,
      localId: localId,
    );
  }

  Future<void> _performSOSUpload({
    required double lat,
    required double lng,
    String? addressDetail,
    required String triggeredBy,
    required String localId,
  }) async {
    // Hentikan jika sudah tidak relevan (dibatalkan user / sudah ada server ID)
    if (!mounted) return;
    if (_sosPhase == 'idle') return;
    // Cek apakah masih relevan: pendingId harus match ATAU activeIncident sudah punya server ID
    if (_pendingIncidentId != null &&
        _pendingIncidentId != localId &&
        _activeIncident?.incidentId != localId) {
      return;
    }

    try {
      final result = await IncidentService.triggerSOS(
        accessToken: widget.accessToken,
        latitude: lat,
        longitude: lng,
        addressDetail: addressDetail,
      );

      if (!mounted) return;

      final bool wasCancelled = _cancelledLocalId == localId;
      final serverId = result.incidentId;

      // Ganti local ID dengan server ID (tidak tampil di UI)
      setState(() {
        if (_pendingIncidentId == localId) {
          _pendingIncidentId = serverId;
        }
        _sosUploadStatus = 'sent';
        _sosTransmitting = true;
        if (_activeIncident != null && _activeIncident!.incidentId == localId) {
          _activeIncident = ActiveIncident(
            incidentId: serverId,
            status: _activeIncident!.status,
            incidentType: _activeIncident!.incidentType,
            latitude: _activeIncident!.latitude,
            longitude: _activeIncident!.longitude,
            createdAt: _activeIncident!.createdAt,
            reporterTrustLabel: _activeIncident!.reporterTrustLabel,
          );
        }
      });

      // Bersihkan pending SOS karena berhasil masuk ke server
      OfflineService.clearPendingSOS();

      // Sync tipe insiden yang tersimpan saat offline
      final pendingType = await OfflineService.getPendingIncidentType();
      if (pendingType != null) {
        try {
          await IncidentService.updateType(
            accessToken: widget.accessToken,
            incidentId: serverId,
            incidentType: pendingType,
          );
          OfflineService.clearPendingIncidentType();
        } catch (_) {
          /* akan di-retry di polling berikutnya */
        }
      }

      if (wasCancelled) {
        IncidentService.cancelSOS(
              accessToken: widget.accessToken,
              incidentId: serverId,
            )
            .then((_) {
              OfflineService.clearPendingCancelSOS();
            })
            .catchError((_) {
              // Jika gagal cancel, simpan ke pending cancel
              OfflineService.savePendingCancelSOS(serverId);
            });
        _cancelledLocalId = null;
      }
    } on SOSBannedException catch (e) {
      OfflineService.clearPendingSOS();
      OfflineService.clearPendingIncidentType();
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
          addressDetail: addressDetail,
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

  Future<void> _onSelectIncidentType(String type, String label) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi Bantuan'.tr(context)),
        content: Text(
          '${'Apakah Anda yakin membutuhkan bantuan segera untuk tipe'.tr(context)} $label?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal'.tr(context),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D00),
              foregroundColor: Colors.white,
            ),
            child: Text('YA, KIRIMKAN SEKARANG'.tr(context)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_pendingIncidentId == null) return;
      // Simpan tipe yang dipilih ke offline cache — akan di-sync setelah upload berhasil
      OfflineService.savePendingIncidentType(type);
      _transitionToBroadcasting(selectedType: type);

      // Hanya panggil updateType jika ID bukan UUID lokal (sudah punya server ID)
      final incidentId = _activeIncident?.incidentId ?? _pendingIncidentId;
      if (incidentId != null && _sosUploadStatus == 'sent') {
        try {
          await IncidentService.updateType(
            accessToken: widget.accessToken,
            incidentId: incidentId,
            incidentType: type,
          );
          OfflineService.clearPendingIncidentType();
        } catch (_) {
          /* akan di-sync setelah upload retry berhasil */
        }
      }
    }
  }

  Future<void> _onGraceTimeout() async {
    if (_pendingIncidentId == null) return;
    final incidentId = _pendingIncidentId!;
    _transitionToBroadcasting();

    try {
      await IncidentService.broadcast(
        accessToken: widget.accessToken,
        incidentId: incidentId,
      );
    } catch (_) {
      /* silent */
    }
  }

  void _transitionToBroadcasting({String? selectedType}) {
    _graceTimer?.cancel();
    _sosRetryTimer?.cancel(); // Cegah retry timer membuat duplikat upload
    if (!mounted) return;
    final incidentId = _pendingIncidentId ?? _activeIncident?.incidentId ?? '';
    if (incidentId.isEmpty) return;
    final newIncident = ActiveIncident(
      incidentId: incidentId,
      status: 'broadcasting',
      incidentType: selectedType ?? 'unknown',
      latitude: 0,
      longitude: 0,
      createdAt: DateTime.now().toIso8601String(),
    );
    setState(() {
      _activeIncident = newIncident;
      // JANGAN null-kan _pendingIncidentId — masih dibutuhkan oleh retry upload
      // _pendingIncidentId akan di-null-kan setelah upload berhasil
      _sosPhase = 'broadcasting';
      _showSOSSentBanner = true;
      // Set status awal transmisi ke false sampai ada HTTP sukses
      _sosTransmitting = false;
    });
    _startLocationUpdates();
    // Update background service dengan incidentId yang valid
    AppBackgroundService.startSOSTracking(incidentId);
    _startStatusPolling();
    _startVibration();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showSOSSentBanner = false);
    });
    _captureAndUploadEvidence(incidentId);
  }

  // ─── Evidence Capture (Tahap 3) ────────────────────────────────────────────────

  /// Mengambil 1 foto dari kamera depan dan 1 foto dari kamera belakang,
  /// serta merekam audio 5 detik secara sepenuhnya di background
  /// (tidak ada UI kamera yang ditampilkan).
  /// File dikirim ke server sebagai bukti situasi SOS.
  Future<void> _captureAndUploadEvidence(String incidentId) async {
    File? frontPhotoFile;
    File? rearPhotoFile;
    File? audioFile;

    // 1. Ambil foto dari kamera depan
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      final xFile = await controller.takePicture();
      await controller.dispose();
      frontPhotoFile = File(xFile.path);
    } catch (_) {
      // Kamera depan tidak tersedia atau ditolak
    }

    // 2. Ambil foto dari kamera belakang
    try {
      final cameras = await availableCameras();
      final rearCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        rearCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      final xFile = await controller.takePicture();
      await controller.dispose();
      rearPhotoFile = File(xFile.path);
    } catch (_) {
      // Kamera belakang tidak tersedia atau ditolak
    }

    // 3. Rekam audio 5 detik
    try {
      final dir = await getTemporaryDirectory();
      final audioPath =
          '${dir.path}/sos_evidence_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final recorder = AudioRecorder();
      if (await recorder.hasPermission()) {
        await recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: audioPath,
        );
        await Future.delayed(const Duration(seconds: 5));
        await recorder.stop();
        audioFile = File(audioPath);
      }
    } catch (_) {
      // Mikrofon tidak tersedia atau ditolak
    }

    // 4. Upload ke server (best-effort, tidak memblokir UI)
    await IncidentService.uploadEvidence(
      accessToken: widget.accessToken,
      incidentId: incidentId,
      photoFile: frontPhotoFile,
      rearPhotoFile: rearPhotoFile,
      audioFile: audioFile,
    );
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
            _nextUpdateCountdown = 3;

            _lastLocationUpdate = null;
          });
          _startCooldown();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Status SOS telah diselesaikan oleh instansi.'.tr(context),
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          setState(() {
            _sosUploadStatus = 'sent';
            _activeIncident = active;
          });
        }
      } catch (_) {
        // Jika error jaringan, biarkan (jangan reset UI), tapi ubah status upload
        if (mounted) setState(() => _sosUploadStatus = 'sending');
      }
    });
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primaryColor = const Color(0xFFFF6B00);
    final isSOSActive = _activeIncident != null || _sosPhase != 'idle';

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w(context),
                vertical: 16.h(context),
              ),
              child: Column(
                children: [
                  HomeHeader(
                    isSOSActive: isSOSActive,
                    primaryColor: primaryColor,
                  ),

                  const Spacer(flex: 2),

                  // ── Active SOS Banner (inline, bukan floating overlay) ────────
                  if (isSOSActive &&
                      !_isLoadingActiveIncident &&
                      _activeIncident != null) ...[
                    ActiveSOSBanner(
                      activeIncident: _activeIncident!,
                      sosTransmitting: _sosTransmitting,
                      nextUpdateCountdown: _nextUpdateCountdown,
                      lastLocationUpdate: _lastLocationUpdate,
                      volunteerPosition: _volunteerPosition,
                      uploadStatusBadgeBuilder: _buildUploadStatusBadge,
                      uploadStatus: _sosUploadStatus,
                    ),
                    SizedBox(height: 12.h(context)),
                  ],

                  const Spacer(flex: 2),

                  // ── SOS Button ────────────────────────────────────────────────
                  ValueListenableBuilder<UserModel>(
                    valueListenable: UserModel.currentUser,
                    builder: (context, UserModel user, _) {
                      final bool missionLocked = user.hasActiveMission;
                      return SOSActionButton(
                        isSOSActive: isSOSActive,
                        tapCount: _tapCount,
                        requiredTaps: _requiredTaps,
                        primaryColor: primaryColor,
                        onTap: isSOSActive ? _onCancelTap : _onSOSTap,
                        isDisabled: missionLocked,
                        disabledReason: missionLocked
                            ? 'Selesaikan/batalkan misi yang sedang aktif'.tr(
                                context,
                              )
                            : null,
                        isCooldown: _sosCooldownSeconds > 0 && !isSOSActive,
                        cooldownSeconds: _sosCooldownSeconds,
                      );
                    },
                  ),

                  const Spacer(flex: 3),

                  // ── Bottom Action Cards ────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: ActionCard(
                          icon: Icons.description_outlined,
                          iconColor: colors.secondary,
                          title: 'Pelaporan'.tr(context),
                          subtitle: 'Kirim bukti & titik\nlokasi'.tr(context),
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
                        ),
                      ),
                      SizedBox(width: 16.w(context)),
                      Expanded(
                        child: ActionCard(
                          icon: Icons.phone_in_talk,
                          iconColor: const Color(0xFFD32F2D),
                          title: 'Panggil 112'.tr(context),
                          subtitle: 'Panggilan darurat\nbebas pulsa'.tr(
                            context,
                          ),
                          onTap: _call112,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h(context)),
                ],
              ),
            ),

            // Grace Period Overlay
            if (_sosPhase == 'gracePeriod') _buildGracePeriodOverlay(colors),

            // SOS Sent Success Banner (Floating)
            if (_showSOSSentBanner) _buildSOSSentBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadStatusBadge() {
    Color color = Colors.grey;
    String label = 'Idle';

    switch (_sosUploadStatus) {
      case 'sending':
        color = Colors.orange;
        label = 'Sending...'.tr(context);
        break;
      case 'sent':
        color = Colors.green;
        label = 'Sent'.tr(context);
        break;
      case 'failed':
        color = Colors.red;
        label = 'Retry...'.tr(context);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGracePeriodOverlay(ColorScheme colors) {
    return Container(
      color: Colors.black87,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'SOS AKAN DIKIRIM DALAM'.tr(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            '$_graceCountdown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 100,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pilih tipe bantuan:'.tr(context),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _typeOption(
                Icons.medical_services,
                'Medis'.tr(context),
                'medical',
              ),
              _typeOption(
                Icons.local_fire_department,
                'Kebakaran'.tr(context),
                'fire',
              ),
              _typeOption(Icons.local_police, 'Kriminal'.tr(context), 'crime'),
              _typeOption(
                Icons.minor_crash,
                'Kecelakaan'.tr(context),
                'accident',
              ),
              _typeOption(Icons.waves, 'Bencana'.tr(context), 'disaster'),
            ],
          ),
          const SizedBox(height: 48),
          TextButton.icon(
            onPressed: () {
              _graceTimer?.cancel();
              _sosRetryTimer?.cancel();
              setState(() {
                _sosPhase = 'idle';
                _pendingIncidentId = null;
                _isTriggeringSOS = false;
                _sosUploadStatus = 'idle';
              });
            },
            icon: const Icon(Icons.close, color: Colors.white),
            label: Text(
              'BATALKAN SEKARANG'.tr(context),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeOption(IconData icon, String label, String value) {
    return GestureDetector(
      onTap: () => _onSelectIncidentType(value, label),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSSentBanner() {
    return Positioned(
      top: 40,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: -60, end: 0),
        builder: (context, value, child) =>
            Transform.translate(offset: Offset(0, value), child: child!),
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bantuan sedang dikoordinasikan.'.tr(context),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _call112() async {
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Batalkan SOS?'.tr(context)),
        content: Text(
          'Pastikan Anda sudah aman atau bantuan sudah tiba.'.tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('TIDAK'.tr(context)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelSOS();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'YA, BATALKAN'.tr(context),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSOS() async {
    if (_activeIncident == null && _pendingIncidentId == null) return;

    final incidentId = _activeIncident?.incidentId ?? _pendingIncidentId;
    if (incidentId == null) return;

    if (_sosUploadStatus == 'sending') {
      _cancelledLocalId = _pendingIncidentId;
    }

    final isOnline = ConnectivityService.isOnline.value;

    _stopVibration();
    _stopLocationUpdates();

    if (mounted) {
      setState(() {
        _activeIncident = null;
        _sosPhase = 'idle';
        _sosUploadStatus = 'idle';
        _tapCount = 0;
        _volunteerPosition = null;
      });
      UserModel.currentUser.value = UserModel.currentUser.value.copyWith(
        isSOSActive: false,
      );
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? 'Panggilan SOS telah dibatalkan.'.tr(context)
                : 'Panggilan SOS dibatalkan (Menunggu koneksi)...'.tr(context),
          ),
          backgroundColor: isOnline ? Colors.green : Colors.orange,
        ),
      );
    }

    if (!isOnline) {
      OfflineService.savePendingCancelSOS(incidentId);
      _attemptSOSCancelBackground(incidentId);
      return;
    }

    try {
      await IncidentService.cancelSOS(
        accessToken: widget.accessToken,
        incidentId: incidentId,
      );
    } catch (_) {
      OfflineService.savePendingCancelSOS(incidentId);
      _attemptSOSCancelBackground(incidentId);
    }
  }

  void _attemptSOSCancelBackground(String incidentId) async {
    bool isCanceled = false;
    while (!isCanceled) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        await IncidentService.cancelSOS(
          accessToken: widget.accessToken,
          incidentId: incidentId,
        );
        await OfflineService.clearPendingCancelSOS();
        isCanceled = true;
      } catch (_) {
        // Abaikan, loop terus tiap 5 detik
      }
    }
  }

  void _showSOSBannedDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Akses Ditolak'.tr(context)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
