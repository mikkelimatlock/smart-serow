import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/config_service.dart';
import '../services/pi_io.dart';

/// Overheat warning screen with shutdown countdown
///
/// Shows current temp, threshold, and countdown to poweroff.
/// When countdown hits zero, executes system shutdown.
class OverheatScreen extends StatefulWidget {
  const OverheatScreen({super.key});

  @override
  State<OverheatScreen> createState() => _OverheatScreenState();
}

class _OverheatScreenState extends State<OverheatScreen> {
  Timer? _countdownTimer;
  Timer? _tempRefreshTimer;
  late int _secondsRemaining;
  double? _currentTemp;

  @override
  void initState() {
    super.initState();

    _secondsRemaining = ConfigService.instance.shutdownDelay.inSeconds;
    _currentTemp = PiIO.instance.getTemperature();

    // Countdown timer - ticks every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        _countdownTimer?.cancel();
        _executeShutdown();
      }
    });

    // Keep temp display updated
    _tempRefreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _currentTemp = PiIO.instance.getTemperature();
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tempRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _executeShutdown() async {
    // Try shutdown commands in order of preference
    // Requires passwordless sudo for 'shutdown' command (see sudoers note below)
    final commands = [
      ['sudo', 'shutdown', '-h', 'now'],
      ['sudo', 'poweroff'],
      ['systemctl', 'poweroff'],  // Might work with polkit
    ];

    for (final cmd in commands) {
      try {
        final result = await Process.run(cmd.first, cmd.skip(1).toList());
        if (result.exitCode == 0) return;  // Success
      } catch (e) {
        // Command not found or other error, try next
      }
    }
    // All failed - we're probably not on Linux or no permissions
    // Pi should have passwordless sudo configured:
    //   echo "pi ALL=(ALL) NOPASSWD: /sbin/shutdown" | sudo tee /etc/sudoers.d/shutdown
  }

  @override
  Widget build(BuildContext context) {
    final threshold = ConfigService.instance.overheatThreshold;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Warning icon
            const Icon(
              Icons.warning_amber_rounded,
              size: 100,
              color: Colors.red,
            ),

            const SizedBox(height: 16),

            // OVERHEATING text
            const Text(
              'OVERHEATING',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.red,
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 48),

            // Current temperature
            Text(
              _currentTemp != null ? '${_currentTemp!.toStringAsFixed(1)}°C' : '—',
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w200,
                color: Colors.white,
                height: 1,
              ),
            ),

            const SizedBox(height: 8),

            // Threshold info
            Text(
              'Threshold: ${threshold.toStringAsFixed(0)}°C',
              style: const TextStyle(
                fontSize: 24,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 48),

            // Countdown
            Text(
              'Shutdown in $_secondsRemaining s',
              style: const TextStyle(
                fontSize: 32,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
