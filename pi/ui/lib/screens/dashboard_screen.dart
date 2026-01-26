import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../services/pi_io.dart';
import '../theme/app_theme.dart';
import '../widgets/navigator_widget.dart';
import '../widgets/stat_box.dart';
import '../widgets/stat_box_main.dart';
import '../widgets/system_bar.dart';

// test service for triggers
import '../services/test_flipflop_service.dart';

/// Main dashboard - displays Pi vitals and placeholder stats
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _random = Random();
  final _navigatorKey = GlobalKey<NavigatorWidgetState>();
  Timer? _timer;

  double? _piTemp;
  int _rpm = 0;
  double _voltage = 12.6;
  int _engineTemp = 25;

  // Placeholder values for system bar
  int? _gpsSatellites;
  int? _lteSignal;

  @override
  void initState() {
    super.initState();

    // Update values periodically
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        // Pi temp - sync read from cache, async refresh happens in background
        _piTemp = PiIO.instance.getTemperature();

        // Placeholder random data - will be replaced with real sensors
        _rpm = 1000 + _random.nextInt(8000);
        _voltage = 11.5 + _random.nextDouble() * 2;
        _engineTemp = 20 + _random.nextInt(60);

        // Placeholder: GPS satellites (null = disconnected, 0 = no fix, 3-12 = typical)
        _gpsSatellites = _random.nextBool() ? _random.nextInt(12) : null;

        // Placeholder: LTE signal (null = disconnected, 0-4 = signal bars)
        _lteSignal = _random.nextBool() ? _random.nextInt(5) : null;
      });
    });

    // DEBUG: flip-flop theme + navigator every 2s
    TestFlipFlopService.instance.start(navigatorKey: _navigatorKey);
  }

  @override
  void dispose() {
    _timer?.cancel();
    TestFlipFlopService.instance.stop();
    super.dispose();
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
                  ),

                  const SizedBox(height: 10),

                  // Main content area - big stat boxes
                  Expanded(
                    flex: 8,
                    child: Row(
                      children: [
                        // Speed - placeholder, will come from GPS
                        StatBoxMain(
                          value: _rpm.toString(),
                          label: 'RPM',
                        ),
                        // Add second StatBoxMain here for 2-up layout:
                        // StatBoxMain(value: '4500', unit: 'rpm', label: 'TACH'),
                      ],
                    ),
                  ),

                  // Bottom stats row
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StatBox(value: _rpm.toString(), label: 'RPM'),
                        StatBox(value: '$_engineTemp', unit: '°C', label: 'ENG'),
                        const StatBox(value: '—', label: 'GEAR'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 32),

            // Right side: Image display (flex: 1)
            Expanded(
              flex: 1,
              child: Center(
                child: NavigatorWidget(key: _navigatorKey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
