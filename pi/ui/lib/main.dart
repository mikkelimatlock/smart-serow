import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const SmartSerowApp());
}

class SmartSerowApp extends StatelessWidget {
  const SmartSerowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Serow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AppRoot(),
    );
  }
}

/// Root widget that manages app state transitions
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _initialized = false;
  String _initStatus = 'Starting...';

  @override
  void initState() {
    super.initState();
    _runInitSequence();
  }

  Future<void> _runInitSequence() async {
    // Simulate init checks - replace with real checks later
    // (UART, GPS, sensors, etc.)

    setState(() => _initStatus = 'Checking systems...');
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() => _initStatus = 'UART: standby');
    await Future.delayed(const Duration(milliseconds: 400));

    setState(() => _initStatus = 'GPS: standby');
    await Future.delayed(const Duration(milliseconds: 400));

    setState(() => _initStatus = 'Ready');
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _initialized
          ? const DashboardScreen(key: ValueKey('dashboard'))
          : SplashScreen(key: const ValueKey('splash'), status: _initStatus),
    );
  }
}

/// Splash screen - shown during initialization
class SplashScreen extends StatelessWidget {
  final String status;

  const SplashScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terrain,
              size: 120,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Smart Serow',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              status,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                _StatBox(label: 'RPM', value: _rpm.toString()),
                _StatBox(label: 'TEMP', value: '$_temp°C'),
                _StatBox(label: 'GEAR', value: '—'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
