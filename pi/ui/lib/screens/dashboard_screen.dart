import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../services/pi_io.dart';
import '../widgets/stat_box.dart';

/// Main dashboard - displays Pi vitals and placeholder stats
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _random = Random();
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SMART SEROW',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.teal,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '${_voltage.toStringAsFixed(1)}V',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _voltage < 12.0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Main Pi temperature display
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _piTemp != null ? _piTemp!.toStringAsFixed(1) : '—',
                      style: const TextStyle(
                        fontSize: 180,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Pi Temp',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StatBox(label: 'RPM', value: _rpm.toString()),
                StatBox(label: 'ENG', value: '$_temp°C'),
                StatBox(label: 'GEAR', value: '—'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
