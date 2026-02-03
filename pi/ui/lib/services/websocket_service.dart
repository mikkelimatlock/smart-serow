import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'backend_service.dart'; // Reuse ArduinoData, GpsData
import 'theme_service.dart';

/// Connection state for WebSocket
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
}

/// Acknowledgment from backend for a command
class CommandAck {
  final String id;
  final String status;
  final String? error;
  final String? extra;

  CommandAck({
    required this.id,
    required this.status,
    this.error,
    this.extra,
  });

  bool get isSuccess => status == 'ok' || status == 'sent';
}

/// Alert from backend
class BackendAlert {
  final String type;
  final String message;

  BackendAlert({required this.type, required this.message});
}

/// Backend status (connection states of GPS/Arduino)
class BackendStatus {
  final bool gpsConnected;
  final bool arduinoConnected;

  BackendStatus({required this.gpsConnected, required this.arduinoConnected});
}

/// WebSocket service for real-time data from backend.
///
/// Replaces HTTP polling with push-based updates.
/// Maintains dual logical channels:
/// - Telemetry: arduino/gps data streams (throttled by backend)
/// - Control: button commands and acknowledgments
class WebSocketService {
  WebSocketService._() {
    _setupStreams();
  }
  static final instance = WebSocketService._();

  static const _serverUrl = 'http://127.0.0.1:5000';

  io.Socket? _socket;
  WsConnectionState _connectionState = WsConnectionState.disconnected;
  Timer? _reconnectTimer;

  // Latest values for sync access (backward compat)
  ArduinoData? _latestArduino;
  GpsData? _latestGps;
  BackendStatus? _latestStatus;

  // Stream controllers
  late StreamController<ArduinoData> _arduinoController;
  late StreamController<GpsData> _gpsController;
  late StreamController<BackendStatus> _statusController;
  late StreamController<CommandAck> _ackController;
  late StreamController<BackendAlert> _alertController;
  late StreamController<WsConnectionState> _connectionController;
  late StreamController<String> _debugController;

  // Debug message buffer
  static const int _maxDebugMessages = 50;
  final List<String> _debugMessages = [];

  void _setupStreams() {
    _arduinoController = StreamController<ArduinoData>.broadcast();
    _gpsController = StreamController<GpsData>.broadcast();
    _statusController = StreamController<BackendStatus>.broadcast();
    _ackController = StreamController<CommandAck>.broadcast();
    _alertController = StreamController<BackendAlert>.broadcast();
    _connectionController = StreamController<WsConnectionState>.broadcast();
    _debugController = StreamController<String>.broadcast();
  }

  /// Log a debug message (adds to buffer and stream)
  void _log(String message) {
    _debugMessages.add(message);
    if (_debugMessages.length > _maxDebugMessages) {
      _debugMessages.removeAt(0);
    }
    _debugController.add(message);
  }

  // --- Public API: Streams ---

  /// Stream of Arduino telemetry updates
  Stream<ArduinoData> get arduinoStream => _arduinoController.stream;

  /// Stream of GPS updates
  Stream<GpsData> get gpsStream => _gpsController.stream;

  /// Stream of backend status updates
  Stream<BackendStatus> get statusStream => _statusController.stream;

  /// Stream of command acknowledgments
  Stream<CommandAck> get ackStream => _ackController.stream;

  /// Stream of alerts from backend
  Stream<BackendAlert> get alertStream => _alertController.stream;

  /// Stream of connection state changes
  Stream<WsConnectionState> get connectionStream => _connectionController.stream;

  /// Stream of debug log messages
  Stream<String> get debugStream => _debugController.stream;

  /// Current debug message buffer (for initial display)
  List<String> get debugMessages => List.unmodifiable(_debugMessages);

  // --- Public API: Sync getters (backward compat) ---

  /// Current connection state
  WsConnectionState get connectionState => _connectionState;

  /// Whether connected to backend
  bool get isConnected => _connectionState == WsConnectionState.connected;

  /// Latest Arduino data (may be null if not yet received)
  ArduinoData? get latestArduino => _latestArduino;

  /// Latest GPS data (may be null if not yet received)
  GpsData? get latestGps => _latestGps;

  /// Latest backend status
  BackendStatus? get latestStatus => _latestStatus;

  // --- Public API: Connection ---

  /// Connect to backend WebSocket
  void connect() {
    if (_socket != null) return; // Already connected or connecting

    _setConnectionState(WsConnectionState.connecting);

    _socket = io.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': false, // We handle reconnection ourselves
    });

    _socket!.onConnect((_) {
      _log('connected');
      _setConnectionState(WsConnectionState.connected);
      _cancelReconnect();
    });

    _socket!.onDisconnect((_) {
      _log('disconnected');
      _setConnectionState(WsConnectionState.disconnected);
      _scheduleReconnect();
    });

    _socket!.onConnectError((error) {
      _log('error: $error');
      _setConnectionState(WsConnectionState.disconnected);
      _scheduleReconnect();
    });

    _socket!.onError((error) {
      _log('error: $error');
    });

    // --- Telemetry Events ---

    _socket!.on('arduino', (data) {
      if (data is Map<String, dynamic>) {
        final arduino = ArduinoData.fromJson(data);
        _latestArduino = arduino;
        _arduinoController.add(arduino);
        final rollStr = arduino.roll != null ? 'r${arduino.roll!.round()}' : '';
        final pitchStr = arduino.pitch != null ? 'p${arduino.pitch!.round()}' : '';
        final imuStr = (rollStr.isNotEmpty || pitchStr.isNotEmpty) ? ' $rollStr$pitchStr' : '';
        _log('ard: ${arduino.rpm ?? "-"}rpm ${arduino.voltage ?? "-"}V g${arduino.gear ?? "-"}$imuStr');

        // Theme switch piggybacks on arduino packets (edge-triggered from backend)
        if (data.containsKey('theme_switch')) {
          final isDark = data['theme_switch'] as bool;
          ThemeService.instance.setDarkMode(isDark);
          _log('theme: ${isDark ? "dark" : "light"}');
        }
      }
    });

    _socket!.on('gps', (data) {
      if (data is Map<String, dynamic>) {
        final gps = GpsData.fromJson(data);
        _latestGps = gps;
        _gpsController.add(gps);
        _log('gps: ${gps.speed?.toStringAsFixed(1) ?? "-"}m/s mode${gps.mode ?? "-"}');
      }
    });

    _socket!.on('status', (data) {
      if (data is Map<String, dynamic>) {
        final status = BackendStatus(
          gpsConnected: data['gps_connected'] ?? false,
          arduinoConnected: data['arduino_connected'] ?? false,
        );
        _latestStatus = status;
        _statusController.add(status);
        _log('status: gps=${status.gpsConnected} ard=${status.arduinoConnected}');

        // Initial theme state comes with status on connect
        if (data.containsKey('theme_switch')) {
          final isDark = data['theme_switch'] as bool;
          ThemeService.instance.setDarkMode(isDark);
          _log('theme: ${isDark ? "dark" : "light"} (initial)');
        }
      }
    });

    // --- Control Events ---

    _socket!.on('ack', (data) {
      if (data is Map<String, dynamic>) {
        final ack = CommandAck(
          id: data['id'] ?? 'unknown',
          status: data['status'] ?? 'unknown',
          error: data['error'],
          extra: data['extra'],
        );
        _ackController.add(ack);
        _log('ack: ${ack.id}=${ack.status}${ack.error != null ? " err:${ack.error}" : ""}');
      }
    });

    _socket!.on('alert', (data) {
      if (data is Map<String, dynamic>) {
        final alert = BackendAlert(
          type: data['type'] ?? 'unknown',
          message: data['message'] ?? '',
        );
        _alertController.add(alert);
        _log('alert: [${alert.type}] ${alert.message}');
      }
    });

    _socket!.connect();
  }

  /// Disconnect from backend
  void disconnect() {
    _cancelReconnect();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _setConnectionState(WsConnectionState.disconnected);
  }

  // --- Public API: Commands ---

  /// Send button event to backend
  void sendButton(String id, String action, [Map<String, dynamic>? params]) {
    if (_socket == null || !isConnected) {
      print('[WS] Cannot send button, not connected');
      return;
    }

    final data = <String, dynamic>{
      'id': id,
      'action': action,
      ...?params,
    };

    _socket!.emit('button', data);
  }

  /// Send emergency signal to backend
  void sendEmergency(String type) {
    if (_socket == null) {
      print('[WS] Cannot send emergency, not connected');
      return;
    }

    // Emergency should be sent even if not fully connected
    _socket!.emit('emergency', {'type': type});
  }

  // --- Private ---

  void _setConnectionState(WsConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionController.add(state);
    }
  }

  void _scheduleReconnect() {
    _cancelReconnect();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      print('[WS] Attempting reconnect...');
      _socket?.dispose();
      _socket = null;
      connect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Dispose all resources (call on app shutdown)
  void dispose() {
    disconnect();
    _arduinoController.close();
    _gpsController.close();
    _statusController.close();
    _ackController.close();
    _alertController.close();
    _connectionController.close();
    _debugController.close();
  }
}
