import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_config.dart';

import '../localization/app_localization.dart';

/// Event type dari WebSocket untuk user masyarakat (reporter SOS).
enum MobileWsEvent {
  agencyHandling, // AGENCY_HANDLING
  volunteerHandling, // VOLUNTEER_HANDLING
  volunteerLocationUpdate, // VOLUNTEER_LOCATION_UPDATE
  reporterLocationUpdate, // REPORTER_LOCATION_UPDATE
  sosCancelled, // SOS_CANCELLED
  sosResolved, // SOS_RESOLVED
  sosFalseAlarm, // SOS_FALSE_ALARM
  incidentAssignmentOffer, // INCIDENT_ASSIGNMENT_OFFER
  incidentAssignmentClaimed, // INCIDENT_ASSIGNMENT_CLAIMED
  forceLogout, // FORCE_LOGOUT — sesi digantikan perangkat lain
  connected,
  unknown,
}

class MobileWsMessage {
  final MobileWsEvent event;
  final Map<String, dynamic> payload;

  const MobileWsMessage({required this.event, required this.payload});

  factory MobileWsMessage.fromRaw(Map<String, dynamic> json) {
    final eventStr = json['event'] as String? ?? '';
    final event = switch (eventStr) {
      'AGENCY_HANDLING' => MobileWsEvent.agencyHandling,
      'VOLUNTEER_HANDLING' => MobileWsEvent.volunteerHandling,
      'VOLUNTEER_LOCATION_UPDATE' => MobileWsEvent.volunteerLocationUpdate,
      'REPORTER_LOCATION_UPDATE' => MobileWsEvent.reporterLocationUpdate,
      'SOS_CANCELLED' => MobileWsEvent.sosCancelled,
      'SOS_RESOLVED' => MobileWsEvent.sosResolved,
      'SOS_FALSE_ALARM' => MobileWsEvent.sosFalseAlarm,
      'INCIDENT_ASSIGNMENT_OFFER' => MobileWsEvent.incidentAssignmentOffer,
      'INCIDENT_ASSIGNMENT_CLAIMED' => MobileWsEvent.incidentAssignmentClaimed,
      'FORCE_LOGOUT' => MobileWsEvent.forceLogout,
      _ => MobileWsEvent.unknown,
    };
    return MobileWsMessage(
      event: event,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// WebSocket service untuk user masyarakat.
/// Digunakan agar reporter SOS menerima notifikasi real-time
/// ketika ada instansi atau relawan yang merespons SOS mereka.
class MobileWsService extends ChangeNotifier {
  final String token;

  MobileWsService({required this.token});

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<MobileWsMessage>.broadcast();
  bool _connected = false;
  bool _disposed = false;

  /// Jika true, sesi ini sudah dihentikan paksa. JANGAN reconnect.
  bool _forceLoggedOut = false;
  Timer? _reconnectTimer;

  /// Consecutive connect failures; reset to 0 on a successful connection.
  int _reconnectAttempt = 0;
  final _random = Random();

  Stream<MobileWsMessage> get eventStream => _controller.stream;
  bool get isConnected => _connected;

  /// True jika sesi ini dihentikan paksa karena login di perangkat lain.
  bool get isForceLoggedOut => _forceLoggedOut;

  /// Mulai koneksi WebSocket.
  //
  // _doConnect is fire-and-forget: connection failures are handled by
  // _scheduleReconnect, so the returned future is intentionally not awaited.
  // ignore: unawaited_futures
  void connect() {
    if (_disposed || _forceLoggedOut) return;
    _doConnect();
  }

  /// Attempts a WebSocket handshake and only treats it as successful once
  /// `ready` completes. `WebSocketChannel.connect` does not await the
  /// underlying connect future, so connection failures surface as stream
  /// errors (`addError`) rather than as a thrown exception here. Resetting the
  /// backoff counter is therefore deferred until after a verified handshake,
  /// which keeps the exponential backoff growing across repeated failures
  /// instead of collapsing back to ~1 s on every attempt.
  Future<void> _doConnect() async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.wsUrl}?token=$token&lang=${AppLocalization.currentLocaleCode}',
      );
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
      );
      // Verify the handshake before marking the connection successful.
      await _channel!.ready;
      _connected = true;
      // Verified successful connection: reset the backoff attempt counter.
      _reconnectAttempt = 0;
      debugPrint('[MobileWS] Connected');
      _controller.add(
        const MobileWsMessage(event: MobileWsEvent.connected, payload: {}),
      );
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[MobileWS] Connect error: $e\n$stackTrace');
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final msg = MobileWsMessage.fromRaw(json);

      // ── FORCE_LOGOUT: hentikan reconnect, emit event, biarkan screen handle ─
      if (msg.event == MobileWsEvent.forceLogout) {
        debugPrint('[MobileWS] FORCE_LOGOUT received — stopping reconnect');
        _forceLoggedOut = true;
        _reconnectTimer?.cancel();
        _connected = false;
        _sub?.cancel();
        _channel?.sink.close();
        _controller.add(msg); // Listener di screen akan handle logout UI
        notifyListeners();
        return;
      }

      _controller.add(msg);
    } catch (e, stackTrace) {
      debugPrint('[MobileWS] Parse error: $e\n$stackTrace');
    }
  }

  void _onError(Object err, [StackTrace? stackTrace]) {
    debugPrint(
      '[MobileWS] Error: $err${stackTrace != null ? '\n$stackTrace' : ''}',
    );
    _connected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[MobileWS] Disconnected');
    _connected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    // Jangan reconnect jika sesi sudah di-force logout atau di-dispose.
    if (_disposed || _forceLoggedOut) return;
    // Jangan gandakan jadwal: jika timer reconnect masih menunggu, jangan
    // menjadwalkan lagi atau meng-increment attempt (mencegah _onError dan
    // _onDone dari satu kegagalan yang sama dari menjadwalkan dua kali).
    if (_reconnectTimer != null) return;
    final delay = computeReconnectDelay(
      attempt: _reconnectAttempt,
      random: _random,
    );
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      // ignore: unawaited_futures
      if (!_disposed && !_forceLoggedOut) _doConnect();
    });
  }

  /// Exponential backoff with ±20% jitter.
  ///
  /// delay = min(cap, base * 2^attempt), then jittered by ±20% of the capped
  /// value. [random] is injected so the function is pure and deterministic in
  /// tests. Returns a non-negative duration.
  static Duration computeReconnectDelay({
    required int attempt,
    Duration base = const Duration(seconds: 1),
    Duration cap = const Duration(seconds: 60),
    Random? random,
  }) {
    final r = random ?? Random();
    var delayMs = base.inMilliseconds.toDouble();
    for (var i = 0; i < attempt; i++) {
      delayMs *= 2;
    }
    if (delayMs > cap.inMilliseconds.toDouble()) {
      delayMs = cap.inMilliseconds.toDouble();
    }
    final jitter = delayMs * 0.2;
    final offset = (r.nextDouble() * 2 - 1) * jitter; // [-jitter, +jitter]
    var resultMs = delayMs + offset;
    if (resultMs < 0) resultMs = 0;
    return Duration(milliseconds: resultMs.round());
  }

  /// Mengirim koordinat lokasi via WebSocket (real-time).
  void sendLocation(double lat, double lng) {
    if (!_connected || _channel == null) return;
    _channel!.sink.add(
      jsonEncode({
        'event': 'UPDATE_LOCATION',
        'payload': {'latitude': lat, 'longitude': lng},
      }),
    );
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _connected = false;
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
    super.dispose();
  }
}
