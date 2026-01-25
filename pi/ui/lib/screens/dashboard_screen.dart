import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../widgets/stat_box.dart';

/// Main dashboard - placeholder with random updating values
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _random = Random();
  Timer? _timer;

  int _speed = 0;
  int _rpm = 0;
  double _voltage = 12.6;
  int _temp = 25;

  @override
  void initState() {
    super.initState();
    // Update random values every 500ms - simulates live data
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _speed = _random.nextInt(120);
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

            // Main speed display
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_speed',
                      style: const TextStyle(
                        fontSize: 180,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Text(
                      'km/h',
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
                StatBox(label: 'TEMP', value: '$_temp°C'),
                StatBox(label: 'GEAR', value: '—'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
