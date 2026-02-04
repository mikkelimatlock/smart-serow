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

    setState(() => _initStatus = 'Checking systems...');
    await Future.delayed(const Duration(milliseconds: 500));

    // Check UART connection via backend health endpoint
    // Also preload navigator images in parallel (usually UART is the bottleneck)
    setState(() => _initStatus = 'UART: connecting...');
    final imagePreloadFuture = _preloadNavigatorImages();
    await _waitForUart();
    await imagePreloadFuture;

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
          final arduinoOk = data['arduino_connected'] == true;

          if (arduinoOk) {
            setState(() => _initStatus = 'UART: OK');
            await Future.delayed(const Duration(milliseconds: 300));
            return;
          }
        }
      } catch (e) {
        // Backend not reachable yet - keep trying
      }

      // Not connected yet
      setState(() => _initStatus = 'UART: waiting...');
      await Future.delayed(retryDelay);
    }

    // Timeout - proceed anyway (UI will show stale data indicators)
    setState(() => _initStatus = 'UART: timeout');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Preload navigator images into Flutter's image cache
  ///
  /// Scans for all PNGs in the navigator folder and precaches them.
  /// Runs silently - no status updates (meant to run parallel with UART).
  Future<void> _preloadNavigatorImages() async {
    final images = await ConfigService.instance.getNavigatorImages();
    for (final file in images) {
      // precacheImage needs a context, but we're in initState territory
      // Use the root context via a post-frame callback workaround
      if (!mounted) return;
      await precacheImage(FileImage(file), context);
    }
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
