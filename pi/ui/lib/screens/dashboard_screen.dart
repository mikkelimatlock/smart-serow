import 'dart:async';
import 'dart:math' show sqrt, sin, cos, pi;
import 'package:flutter/material.dart';

import '../services/backend_service.dart';
import '../services/websocket_service.dart';
import '../services/pi_io.dart';
import '../theme/app_theme.dart';
import '../widgets/navigator_widget.dart';
import '../widgets/stat_box.dart';
import '../widgets/stat_box_main.dart';
import '../widgets/system_bar.dart';
import '../widgets/debug_console.dart';
import '../widgets/whiskey_mark.dart';
import '../widgets/accel_graph.dart';
import '../widgets/gps_compass.dart';

// test service for triggers
import '../services/test_flipflop_service.dart';

/// Main dashboard - displays Pi vitals and placeholder stats
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _surpriseThreshold = 0.24; // G threshold for navigator surprise

  final _navigatorKey = GlobalKey<NavigatorWidgetState>();

  // Timer for Pi temp only (safety critical, direct file read)
  Timer? _piTempTimer;

  // WebSocket stream subscriptions
  StreamSubscription<ArduinoData>? _arduinoSub;
  StreamSubscription<GpsData>? _gpsSub;
  StreamSubscription<WsConnectionState>? _connectionSub;

  // Pi temperature - direct file read (safety critical)
  double? _piTemp;

  // From backend - Arduino data
  int? _rpm;
  double? _voltage;
  int? _engineTemp;
  int? _gear;
  double? _roll;
  double? _pitch;
  double? _ax;
  double? _ay;
  double? _dynamicAx;  // Gravity-compensated
  double? _dynamicAy;

  // From backend - GPS data
  double? _gpsSpeed;
  double? _gpsTrack;

  // Placeholder values for system bar
  int? _gpsSatellites;
  int? _lteSignal;

  // WebSocket connection state
  WsConnectionState _wsState = WsConnectionState.disconnected;

  @override
  void initState() {
    super.initState();

    // Connect to WebSocket
    WebSocketService.instance.connect();

    // Subscribe to Arduino data stream
    _arduinoSub = WebSocketService.instance.arduinoStream.listen((data) {
      // Gravity-compensated acceleration
      // When tilted, gravity "leaks" into horizontal axes - subtract it out
      final rollRad = (data.roll ?? 0) * pi / 180;
      final pitchRad = (data.pitch ?? 0) * pi / 180;

      // Subtract gravity leakage from measured acceleration
      // Axes swapped for IMU mounting orientation
      final dynamicAx = (data.ay ?? 0) + sin(rollRad);
      final dynamicAy = (data.ax ?? 0) - (sin(pitchRad) * cos(rollRad));

      setState(() {
        _voltage = data.voltage;
        _rpm = data.rpm;
        _engineTemp = data.engTemp;
        _gear = data.gear;
        _roll = data.roll;
        _pitch = data.pitch;
        _ax = data.ax;
        _ay = data.ay;
        _dynamicAx = dynamicAx;
        _dynamicAy = dynamicAy;
      });

      final gMagnitude = sqrt(dynamicAx * dynamicAx + dynamicAy * dynamicAy);
      if (gMagnitude > _surpriseThreshold) {
        _navigatorKey.currentState?.setEmotion('surprise');
      }
    });

    // Subscribe to GPS data stream
    _gpsSub = WebSocketService.instance.gpsStream.listen((data) {
      setState(() {
        _gpsSpeed = data.speed;
        _gpsTrack = data.track;
        _gpsSatellites = data.satellites;
      });
    });

    // Subscribe to connection state
    _connectionSub = WebSocketService.instance.connectionStream.listen((state) {
      setState(() {
        _wsState = state;
      });
    });

    // Timer for Pi temp only (safety critical - bypasses backend)
    _piTempTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _piTemp = PiIO.instance.getTemperature();
      });
    });

    // Initialize with any cached data from WebSocketService
    final cachedArduino = WebSocketService.instance.latestArduino;
    if (cachedArduino != null) {
      _voltage = cachedArduino.voltage;
      _rpm = cachedArduino.rpm;
      _engineTemp = cachedArduino.engTemp;
      _gear = cachedArduino.gear;
      _roll = cachedArduino.roll;
      _pitch = cachedArduino.pitch;
      _ax = cachedArduino.ax;
      _ay = cachedArduino.ay;
    }

    final cachedGps = WebSocketService.instance.latestGps;
    if (cachedGps != null) {
      _gpsSpeed = cachedGps.speed;
      _gpsTrack = cachedGps.track;
      _gpsSatellites = cachedGps.satellites;
    }

    _wsState = WebSocketService.instance.connectionState;

    // Placeholder: LTE signal (TODO: wire up when LTE service exists)
    _lteSignal = null;

    // DEBUG: flip-flop theme + navigator every 2s
    TestFlipFlopService.instance.start(navigatorKey: _navigatorKey);
  }

  @override
  void dispose() {
    _piTempTimer?.cancel();
    _arduinoSub?.cancel();
    _gpsSub?.cancel();
    _connectionSub?.cancel();
    TestFlipFlopService.instance.stop();
    super.dispose();
  }

  /// Format gear for display: null → "—", 0 → "N", 1-6 → "1"-"6"
  String _formatGear(int? gear) {
    if (gear == null) return '—';
    if (gear == 0) return 'N';
    return gear.toString();
  }

  /// Format nullable int for display
  String _formatInt(int? value) => value?.toString() ?? '—';

  /// Format nullable double for display with decimal places
  String _formatDouble(double? value, [int decimals = 1]) {
    if (value == null) return '—';
    return value.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Left side: All dashboard widgets (flex: 2)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // System status bar
                  SystemBar(
                    gpsSatellites: _gpsSatellites,
                    lteSignal: _lteSignal,
                    piTemp: _piTemp,
                    voltage: _voltage,
                    wsState: _wsState,
                  ),

                  // Main content area - big widgets
                  Expanded(
                    flex: 7,
                    child: Row(
                      children: [
                        // Attitude indicator (whiskey mark)
                        Expanded(
                          child: WhiskeyMark(
                            roll: _roll,
                            pitch: _pitch,
                          ),
                        ),
                        Expanded(
                          child: AccelGraph(
                            ax: _dynamicAx,  // Gravity-compensated lateral
                            ay: _dynamicAy,  // Gravity-compensated longitudinal
                            maxG: 0.8,
                            ghostTrackPeriod: const Duration(seconds: 4),
                          ),
                        )
                      ],
                    ),
                  ),

                  // Bottom stats row
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StatBox(value: _formatInt(_rpm), label: 'RPM', isWarning: () => (_rpm ?? 0) > 4000),
                        GpsCompass(heading: _gpsTrack),
                        StatBox(value: _formatGear(_gear), label: 'GEAR'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 32),

            // Right side: Navigator on top, debug console below
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  // Navigator
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: NavigatorWidget(key: _navigatorKey),
                    ),
                  ),
                  // Debug console
                  Expanded(
                    flex: 1,
                    child: 
                    DebugConsole(
                      messageStream: WebSocketService.instance.debugStream,
                      initialMessages: WebSocketService.instance.debugMessages,
                      maxLines: 6,
                      title: 'WebSocket messages',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
