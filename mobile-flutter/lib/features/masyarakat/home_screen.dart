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
import '../../core/services/incident_service.dart';
import '../../core/services/location_controller.dart';
import '../../core/services/location_service.dart';
import '../../core/services/mobile_ws_service.dart';
import '../../core/services/user_service.dart';
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
      10; // hitung mundur update lokasi berikutnya (detik)
  DateTime? _lastLocationUpdate; // timestamp lokasi terakhir berhasil diupdate
  bool _sosTransmitting = true; // apakah koneksi SOS dalam keadaan baik
  Timer? _countdownTimer; // hitung mundur 1 detik

  // Untuk menyimpan ID insiden lokal jika user membatalkan saat proses upload masih berlangsung
  String? _cancelledLocalId;

  // ─── Lokasi Relawan (Poin 4) ─────────────────────────────────────────────────
  // Posisi terkini relawan yang sedang menangani SOS ini (dari WS)
  ({double lat, double lng, String? address, String? updatedAt})?
  _volunteerPosition;

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
    LocationController.instance.start();
    // Heartbeat ping setiap 30 detik
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      UserService.ping(widget.accessToken);
    });
    UserService.ping(widget.accessToken);
    // WebSocket real-time
    _ws = MobileWsService(token: widget.accessToken);
    _ws!.connect();
    _wsSub = _ws!.eventStream.listen(_onWsEvent);
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

  /// Dipanggil saat ada instansi atau relawan yang mulai handle.
  void _onHandlerArrived({required bool byAgency}) {
    _stopVibration();
    Vibration.vibrate(duration: 800); // konfirmasi 1x getaran panjang
    _checkHandlerStatus(); // refresh status
    if (!mounted) return;
    final msg = byAgency
        ? '🏛️ Instansi sedang dalam perjalanan ke lokasi Anda!'
        : '🦺 Relawan sedang menuju lokasi Anda!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.tr(context)),
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
    _wsSub?.cancel();
    if (_ws != null) {
      _ws!.dispose();
    }
    LocationController.instance.stop();
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
    _locationUpdateTimer?.cancel();
    _nextUpdateCountdown = 10;
    _lastLocationUpdate = DateTime.now();
    _sosTransmitting = true;
    _startCountdownTimer();

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (
      _,
    ) async {
      if (_activeIncident == null || !mounted) return;

      setState(() {
        _nextUpdateCountdown = 10;
        _sosTransmitting = true;
      });

      // 1. Cek apakah SOS masih aktif di server (sekaligus ambil status penangan terbaru)
      try {
        final active = await IncidentService.getActive(
          accessToken: widget.accessToken,
        );
        if (!mounted) return;
        if (active == null) {
          _stopVibration();
          _stopLocationUpdates();
          setState(() => _activeIncident = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Status SOS telah diselesaikan oleh instansi.'.tr(context),
              ),
              backgroundColor: Colors.green,
            ),
          );
          return;
        }
        // Update activeIncident (termasuk status penangan terbaru)
        if (mounted) {
          setState(() {
            _activeIncident = active;
            _lastLocationUpdate = DateTime.now();
          });
          // Hentikan vibration jika ada yang handle
          if (active.isBeingHandled) {
            _stopVibration();
          } else {
            _startVibration();
          }
        }
      } catch (_) {
        if (mounted) setState(() => _sosTransmitting = false);
      }

      // 2. Kirim posisi GPS dari LocationController (tidak ada panggilan GPS duplikat)
      final pos = LocationController.instance.position.value;
      if (pos != null && _activeIncident != null) {
        try {
          await IncidentService.updateLocation(
            accessToken: widget.accessToken,
            incidentId: _activeIncident!.incidentId,
            latitude: pos.lat,
            longitude: pos.lng,
          );
          if (mounted) {
            setState(() {
              _lastLocationUpdate = DateTime.now();
              _sosTransmitting = true;
              // Reset countdown tepat saat update lokasi berhasil
              _nextUpdateCountdown = 10;
            });
            // Restart countdown timer dari 10 agar sinkron
            _startCountdownTimer();
          }
        } catch (_) {
          if (mounted) {
            setState(() => _sosTransmitting = false);
          }
        }
      }
    });
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

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  // ─── SOS Tap Logic (Send) ────────────────────────────────────────────────────

  void _onSOSTap() {
    // Blokir jika akun di-ban
    if (widget.isSOSBanned) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun Anda diblokir dari fitur SOS. Hubungi admin.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
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
        LocationService.requestPermission(context);
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
    if (_pendingIncidentId != null && _pendingIncidentId != localId) return;

    try {
      final result = await IncidentService.triggerSOS(
        accessToken: widget.accessToken,
        latitude: lat,
        longitude: lng,
        addressDetail: addressDetail,
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
    final incidentId = _pendingIncidentId!;
    final newIncident = ActiveIncident(
      incidentId: incidentId,
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
    _startStatusPolling();
    _startVibration(); // Mulai getaran saat SOS aktif
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showSOSSentBanner = false);
    });
    _captureAndUploadEvidence(incidentId);
  }

  // ─── Evidence Capture (Tahap 3) ────────────────────────────────────────────────

  /// Mengambil 1 foto dari kamera depan dan merekam audio 5 detik secara
  /// sepenuhnya di background (tidak ada UI kamera yang ditampilkan).
  /// File dikirim ke server sebagai bukti situasi SOS.
  Future<void> _captureAndUploadEvidence(String incidentId) async {
    File? photoFile;
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
      photoFile = File(xFile.path);
    } catch (_) {
      // Kamera tidak tersedia atau ditolak - lanjutkan ke audio
    }

    // 2. Rekam audio 5 detik
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

    // 3. Upload ke server (best-effort, tidak memblokir UI)
    await IncidentService.uploadEvidence(
      accessToken: widget.accessToken,
      incidentId: incidentId,
      photoFile: photoFile,
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
            _nextUpdateCountdown = 10;
            _lastLocationUpdate = null;
          });
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
        }
      } catch (_) {
        // Jika error jaringan, biarkan (jangan reset UI)
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  HomeHeader(
                    isSOSActive: isSOSActive,
                    primaryColor: primaryColor,
                  ),

                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ── SOS Button (Centered in the available space) ──
                        SOSActionButton(
                          isSOSActive: isSOSActive,
                          tapCount: _tapCount,
                          requiredTaps: _requiredTaps,
                          primaryColor: primaryColor,
                          onTap: isSOSActive ? _onCancelTap : _onSOSTap,
                        ),

                        // ── Active SOS status banner (Floating at the top of this area) ──
                        if (isSOSActive &&
                            !_isLoadingActiveIncident &&
                            _activeIncident != null)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: ActiveSOSBanner(
                              activeIncident: _activeIncident!,
                              sosTransmitting: _sosTransmitting,
                              nextUpdateCountdown: _nextUpdateCountdown,
                              lastLocationUpdate: _lastLocationUpdate,
                              volunteerPosition: _volunteerPosition,
                              uploadStatusBadgeBuilder: _buildUploadStatusBadge,
                            ),
                          ),
                      ],
                    ),
                  ),

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
                      const SizedBox(width: 16),
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
                  const SizedBox(height: 24),
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
              _typeOption(Icons.medical_services, 'Medis', 'medical'),
              _typeOption(Icons.local_fire_department, 'Kebakaran', 'fire'),
              _typeOption(Icons.local_police, 'Kriminal', 'crime'),
              _typeOption(Icons.minor_crash, 'Kecelakaan', 'accident'),
              _typeOption(Icons.waves, 'Bencana', 'disaster'),
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
      onTap: () => _onSelectIncidentType(value),
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

    try {
      if (_sosUploadStatus == 'sending') {
        _cancelledLocalId = _pendingIncidentId;
      }

      await IncidentService.cancelSOS(
        accessToken: widget.accessToken,
        incidentId: incidentId,
      );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Panggilan SOS telah dibatalkan.'.tr(context)),
            backgroundColor: const Color(0xFF50C878),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan SOS. Coba lagi.'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
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
