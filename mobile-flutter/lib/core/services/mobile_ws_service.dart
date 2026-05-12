import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_config.dart';

/// Event type dari WebSocket untuk user masyarakat (reporter SOS).
enum MobileWsEvent {
  agencyHandling,         // AGENCY_HANDLING         - instansi mulai menangani
  volunteerHandling,      // VOLUNTEER_HANDLING       - relawan on the way
  volunteerLocationUpdate,// VOLUNTEER_LOCATION_UPDATE - update posisi relawan
  sosCancelled,           // SOS_CANCELLED            - SOS dibatalkan
  sosResolved,            // SOS_RESOLVED             - SOS diselesaikan
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
      'SOS_CANCELLED'            => MobileWsEvent.sosCancelled,
      'SOS_RESOLVED'             => MobileWsEvent.sosResolved,
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
  Timer? _reconnectTimer;

  Stream<MobileWsMessage> get eventStream => _controller.stream;
  bool get isConnected => _connected;

  /// Mulai koneksi WebSocket.
  void connect() {
    if (_disposed) return;
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
      _controller.add(const MobileWsMessage(event: MobileWsEvent.connected, payload: {}));
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
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_disposed) _doConnect();
    });
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
