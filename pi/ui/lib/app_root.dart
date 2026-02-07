import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  final Map<String, String> _initStatuses = {};

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

  void _updateStatus(String key, String value) {
    setState(() => _initStatuses[key] = value);
  }

  Future<void> _runInitSequence() async {
    // Show all items from the start so the row doesn't jump around
    _updateStatus('Config', '...');
    _updateStatus('UART', '...');
    _updateStatus('Navigator', '...');

    // Config must load first (everything else depends on it)
    _updateStatus('Config', 'Loading');
    await ConfigService.instance.load();
    _updateStatus('Config', 'Ready');

    // UART health check and navigator image preload run truly in parallel
    _updateStatus('UART', 'Connecting');
    _updateStatus('Navigator', 'Loading');
    await Future.wait([
      _waitForUart(),
      _preloadNavigatorImages(),
    ]);

    // Let the user see the all-ready state for a moment
    await Future.delayed(const Duration(milliseconds: 500));

    // Start overheat monitoring
    OverheatMonitor.instance.start(
      onOverheat: () {
        setState(() => _overheatTriggered = true);
      },
    );

    setState(() => _initialized = true);
  }

  /// Poll backend health endpoint until Arduino is connected
  Future<void> _waitForUart() async {
    final backendUrl = ConfigService.instance.backendUrl;
    const maxAttempts = 30; // ~30 seconds max wait
    const retryDelay = Duration(seconds: 1);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await http
            .get(Uri.parse('$backendUrl/health'))
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['arduino_connected'] == true) {
            _updateStatus('UART', 'Ready');
            return;
          }
        }
      } catch (e) {
        // Backend not reachable yet - keep trying
      }

      _updateStatus('UART', 'Waiting');
      await Future.delayed(retryDelay);
    }

    // Timeout - proceed anyway (UI will show stale data indicators)
    _updateStatus('UART', 'Timeout');
  }

  /// Preload navigator images into Flutter's image cache
  ///
  /// Scans for all PNGs in the navigator folder and precaches them.
  Future<void> _preloadNavigatorImages() async {
    final images = await ConfigService.instance.getNavigatorImages();
    for (final file in images) {
      if (!mounted) return;
      await precacheImage(FileImage(file), context);
    }
    _updateStatus('Navigator', 'Ready');
  }

  @override
  Widget build(BuildContext context) {
    // Determine which screen to show (priority: overheat > splash > dashboard)
    Widget child;
    if (_overheatTriggered) {
      child = const OverheatScreen(key: ValueKey('overheat'));
    } else if (!_initialized) {
      child = SplashScreen(key: const ValueKey('splash'), statuses: _initStatuses);
    } else {
      child = const DashboardScreen(key: ValueKey('dashboard'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: child,
    );
  }
}
