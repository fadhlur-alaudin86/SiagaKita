import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_config.dart';
import 'session_service.dart';

enum ResponderWsEvent {
  incidentAssignmentOffer,
  agencyHandling,
  sosCancelled,
  sosResolved,
  forceLogout,
  connected,
  disconnected,
  unknown,
}

class ResponderWsMessage {
  final ResponderWsEvent event;
  final Map<String, dynamic> payload;

  const ResponderWsMessage({required this.event, required this.payload});

  factory ResponderWsMessage.fromJson(Map<String, dynamic> json) {
    final eventStr = json['event'] as String? ?? '';
    final event = switch (eventStr) {
      'INCIDENT_ASSIGNMENT_OFFER' => ResponderWsEvent.incidentAssignmentOffer,
      'AGENCY_HANDLING' => ResponderWsEvent.agencyHandling,
      'SOS_CANCELLED' => ResponderWsEvent.sosCancelled,
      'SOS_RESOLVED' => ResponderWsEvent.sosResolved,
      'FORCE_LOGOUT' => ResponderWsEvent.forceLogout,
      _ => ResponderWsEvent.unknown,
    };
    return ResponderWsMessage(
      event: event,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// WebSocket service for official agency field personnel.
/// Maintains persistent connection, handles reconnects, and notifies UI of incoming dispatches.
class ResponderWsService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final _eventController = StreamController<ResponderWsMessage>.broadcast();
  Stream<ResponderWsMessage> get onEvent => _eventController.stream;

  Future<void> connect() async {
    disconnect();

    final token = await SessionService.getToken();
    if (token == null || token.isEmpty) return;

    final lang = await SessionService.getLocale();
    final uri = Uri.parse('${ApiConfig.wsUrl}?token=$token&lang=$lang');

    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      _isConnected = true;
      notifyListeners();
      _startHeartbeat();
      debugPrint('[ResponderWsService] Connected to WebSocket server');
    } catch (e) {
      debugPrint('[ResponderWsService] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data.toString()) as Map<String, dynamic>;
      final message = ResponderWsMessage.fromJson(json);

      if (message.event == ResponderWsEvent.forceLogout) {
        SessionService.clear();
      }

      _eventController.add(message);
      notifyListeners();
    } catch (e) {
      debugPrint('[ResponderWsService] Error parsing incoming message: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[ResponderWsService] WebSocket error: $error');
    _handleDisconnect();
  }

  void _onDone() {
    debugPrint('[ResponderWsService] WebSocket closed');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _stopHeartbeat();
    notifyListeners();
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'event': 'PING', 'payload': {}}));
        } catch (_) {}
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      final isLoggedIn = await SessionService.isLoggedIn();
      if (isLoggedIn) {
        connect();
      }
    });
  }

  void disconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _subscription = null;
    _channel = null;
    _isConnected = false;
  }

  @override
  void dispose() {
    disconnect();
    _eventController.close();
    super.dispose();
  }
}
