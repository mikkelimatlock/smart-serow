import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../services/pi_io.dart';
import '../theme/app_theme.dart';
import '../widgets/navigator_widget.dart';
import '../widgets/stat_box.dart';

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
  int _temp = 25;

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
        _temp = 20 + _random.nextInt(60);
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
        padding: const EdgeInsets.all(32),
        child: Row(
          children: [
            // Left side: All dashboard widgets (flex: 2)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header (voltage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Chassis voltage ',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 60,
                            color: theme.subdued,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${_voltage.toStringAsFixed(1)}V',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 80,
                            color: _voltage < 11.9 ? theme.highlight : theme.foreground,
                          ),
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Main Pi temperature display
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _piTemp != null ? _piTemp!.toStringAsFixed(1) : '—',
                            style: TextStyle(
                              fontSize: 250,
                              fontWeight: FontWeight.w200,
                              color: theme.foreground,
                              height: 1,
                            ),
                          ),
                          Text(
                            'Pi Temp',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontSize: 80,
                              color: theme.subdued,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StatBox(label: 'RPM', value: _rpm.toString()),
                      StatBox(label: 'ENG', value: '$_temp°C'),
                      StatBox(label: 'GEAR', value: '—'),
                    ],
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
