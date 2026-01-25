import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';

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
