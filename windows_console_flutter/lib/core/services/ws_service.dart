import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_constants.dart';
import '../models/models.dart';

// ─── Event types broadcast dari backend ───────────────────────────────────────

enum WsEvent {
  incomingEmergency,
  sosCancelled,
  rescueAccepted,
  locationUpdate,
  volunteerLocationUpdate,
  sosStatusUpdate,
  incidentUpdated,  // INCIDENT_UPDATED — trigger auto-refresh di console
  forceLogout,      // FORCE_LOGOUT — sesi digantikan (tidak relevan untuk console, tapi disiapkan)
  connected,
  unknown,
}

class WsMessage {
  final WsEvent event;
  final Map<String, dynamic> payload;

  const WsMessage({required this.event, required this.payload});

  factory WsMessage.fromRaw(Map<String, dynamic> json) {
    final eventStr = json['event'] as String? ?? '';
    final event = switch (eventStr) {
      'INCOMING_EMERGENCY'      => WsEvent.incomingEmergency,
      'SOS_CANCELLED'           => WsEvent.sosCancelled,
      'RESCUE_ACCEPTED'         => WsEvent.rescueAccepted,
      'LOCATION_UPDATE'         => WsEvent.locationUpdate,
      'VOLUNTEER_LOCATION_UPDATE'=> WsEvent.volunteerLocationUpdate,
      'SOS_STATUS_UPDATE'       => WsEvent.sosStatusUpdate,
      'INCIDENT_UPDATED'        => WsEvent.incidentUpdated,
      'FORCE_LOGOUT'            => WsEvent.forceLogout,
      _                         => WsEvent.unknown,
    };
    return WsMessage(
      event: event,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    );
  }
}

// ─── WsService — Singleton WebSocket ──────────────────────────────────────────

class WsService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeatTimer;
  bool _connected = false;
  bool _isReconnecting = false;
  String? _token;

  // Live state yang diupdate oleh event WS
  final List<IncidentModel> _liveIncidents = [];

  // Stream controller untuk subscriber individual (audio, map, dll)
  final _controller = StreamController<WsMessage>.broadcast();

  bool get isConnected => _connected;
  List<IncidentModel> get liveIncidents => List.unmodifiable(_liveIncidents);
  Stream<WsMessage> get eventStream => _controller.stream;

  /// True jika sesi ini dihentikan paksa karena FORCE_LOGOUT.
  bool get isForceLoggedOut => _forceLoggedOut;
  bool _forceLoggedOut = false;

  // ─── Connect ────────────────────────────────────────────────────────────────

  Future<void> connect(String token) async {
    if (_connected || _isReconnecting || _forceLoggedOut) return;
    _token = token;

    final uri = Uri.parse('${ApiConstants.wsUrl}?token=$token');
    _channel = WebSocketChannel.connect(uri);
    _sub = _channel!.stream.listen(_onData, onError: _onError, onDone: _onDone);
    _connected = true;
    _isReconnecting = false;
    notifyListeners();
    debugPrint('[WS] Connected');

    // Heartbeat: kirim pesan PING JSON setiap 30 detik agar koneksi tidak di-idle-timeout oleh backend/proxy
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connected) {
        try {
          _channel?.sink.add(jsonEncode({'event': 'PING', 'payload': {}}));
        } catch (_) {}
      }
    });

    // Beritahu subscriber bahwa koneksi (ulang) sukses, agar bisa sinkronisasi ulang
    _controller.add(const WsMessage(event: WsEvent.connected, payload: {}));
  }

  // ─── Event handler ──────────────────────────────────────────────────────────

  void _onData(dynamic raw) async {
    try {
      final json = await Isolate.run(() => jsonDecode(raw as String) as Map<String, dynamic>);
      final msg = WsMessage.fromRaw(json);

      switch (msg.event) {
        case WsEvent.incomingEmergency:
          final inc = IncidentModel.fromJson(msg.payload);
          _liveIncidents.removeWhere((e) => e.id == inc.id);
          _liveIncidents.insert(0, inc);
          notifyListeners();

        case WsEvent.sosCancelled:
          final id = msg.payload['sos_id']?.toString() ?? '';
          _liveIncidents.removeWhere((e) => e.id == id);
          notifyListeners();

        // INCIDENT_UPDATED: notifikasi ke subscriber agar halaman auto-refresh
        case WsEvent.incidentUpdated:
          notifyListeners();

        // FORCE_LOGOUT: hentikan reconnect, biarkan app handle redirect
        case WsEvent.forceLogout:
          debugPrint('[WS] FORCE_LOGOUT received');
          _forceLoggedOut = true;
          _heartbeatTimer?.cancel();
          _sub?.cancel();
          _channel?.sink.close();
          _connected = false;
          _isReconnecting = false;
          _controller.add(msg);
          notifyListeners();
          return;

        case WsEvent.rescueAccepted:
        case WsEvent.locationUpdate:
        case WsEvent.volunteerLocationUpdate:
        case WsEvent.sosStatusUpdate:
        case WsEvent.connected:
        case WsEvent.unknown:
          break;
      }

      _controller.add(msg);
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }

  void _onError(Object err) {
    _connected = false;
    notifyListeners();
    debugPrint('[WS] Error: $err');
    _reconnect();
  }

  void _onDone() {
    _connected = false;
    notifyListeners();
    debugPrint('[WS] Connection closed, reconnecting...');
    _reconnect();
  }

  void _reconnect() {
    if (_isReconnecting || _forceLoggedOut) return;
    _isReconnecting = true;
    _connected = false;
    _heartbeatTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _sub = null;
    _channel = null;
    Future.delayed(const Duration(seconds: 5), () {
      _isReconnecting = false;
      if (_token != null && !_forceLoggedOut) connect(_token!);
    });
  }

  // ─── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    _controller.close();
    super.dispose();
  }
}
