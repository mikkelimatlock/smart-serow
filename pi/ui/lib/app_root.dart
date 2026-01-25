import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/overheat_screen.dart';
import 'services/config_service.dart';
import 'services/overheat_monitor.dart';

/// Root widget that manages app state transitions
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _initialized = false;
  bool _overheatTriggered = false;
  String _initStatus = 'Starting...';

  @override
  void initState() {
    super.initState();
    _runInitSequence();
  }

  @override
  void dispose() {
    OverheatMonitor.instance.stop();
    super.dispose();
  }

  Future<void> _runInitSequence() async {
    // Load config first
    setState(() => _initStatus = 'Loading config...');
    await ConfigService.instance.load();

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

    // Start overheat monitoring
    OverheatMonitor.instance.start(
      onOverheat: () {
        setState(() => _overheatTriggered = true);
      },
    );

    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    // Determine which screen to show (priority: overheat > splash > dashboard)
    Widget child;
    if (_overheatTriggered) {
      child = const OverheatScreen(key: ValueKey('overheat'));
    } else if (!_initialized) {
      child = SplashScreen(key: const ValueKey('splash'), status: _initStatus);
    } else {
      child = const DashboardScreen(key: ValueKey('dashboard'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: child,
    );
  }
}
