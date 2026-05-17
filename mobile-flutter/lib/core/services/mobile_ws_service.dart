import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_config.dart';

/// Event type dari WebSocket untuk user masyarakat (reporter SOS).
enum MobileWsEvent {
  agencyHandling,         // AGENCY_HANDLING
  volunteerHandling,      // VOLUNTEER_HANDLING
  volunteerLocationUpdate, // VOLUNTEER_LOCATION_UPDATE
  reporterLocationUpdate, // REPORTER_LOCATION_UPDATE
  sosCancelled,           // SOS_CANCELLED
  sosResolved,            // SOS_RESOLVED
  sosFalseAlarm,          // SOS_FALSE_ALARM
  forceLogout,            // FORCE_LOGOUT — sesi digantikan perangkat lain
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
      'AGENCY_HANDLING'          => MobileWsEvent.agencyHandling,
      'VOLUNTEER_HANDLING'       => MobileWsEvent.volunteerHandling,
      'VOLUNTEER_LOCATION_UPDATE'=> MobileWsEvent.volunteerLocationUpdate,
      'REPORTER_LOCATION_UPDATE' => MobileWsEvent.reporterLocationUpdate,
      'SOS_CANCELLED'            => MobileWsEvent.sosCancelled,
      'SOS_RESOLVED'             => MobileWsEvent.sosResolved,
      'SOS_FALSE_ALARM'          => MobileWsEvent.sosFalseAlarm,
      'FORCE_LOGOUT'             => MobileWsEvent.forceLogout,
      _                          => MobileWsEvent.unknown,
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

  Stream<MobileWsMessage> get eventStream => _controller.stream;
  bool get isConnected => _connected;

  /// True jika sesi ini dihentikan paksa karena login di perangkat lain.
  bool get isForceLoggedOut => _forceLoggedOut;

  /// Mulai koneksi WebSocket.
  void connect() {
    if (_disposed || _forceLoggedOut) return;
    _doConnect();
  }

  void _doConnect() {
    try {
      final uri = Uri.parse('${ApiConfig.wsUrl}?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
      );
      _connected = true;
      debugPrint('[MobileWS] Connected');
      _controller.add(
        const MobileWsMessage(event: MobileWsEvent.connected, payload: {}),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[MobileWS] Connect error: $e');
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
    } catch (e) {
      debugPrint('[MobileWS] Parse error: $e');
    }
  }

  void _onError(Object err) {
    debugPrint('[MobileWS] Error: $err');
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
    // Jangan reconnect jika sesi sudah di-force logout atau di-dispose
    if (_disposed || _forceLoggedOut) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_disposed && !_forceLoggedOut) _doConnect();
    });
  }

  /// Mengirim koordinat lokasi via WebSocket (real-time).
  void sendLocation(double lat, double lng) {
    if (!_connected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'event': 'UPDATE_LOCATION',
      'payload': {'latitude': lat, 'longitude': lng},
    }));
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
