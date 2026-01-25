import 'dart:async';

import 'config_service.dart';
import 'pi_io.dart';

/// Monitors CPU temperature and triggers overheat condition
///
/// Singleton pattern. Polls temp at 500ms intervals to match dashboard.
/// When temp exceeds threshold for trigger duration, fires callback.
class OverheatMonitor {
  OverheatMonitor._();
  static final instance = OverheatMonitor._();

  Timer? _timer;
  int _consecutiveOverheatSamples = 0;
  bool _triggered = false;

  static const Duration _pollInterval = Duration(milliseconds: 500);

  /// Current temperature (from PiIO cache)
  double? get currentTemp => PiIO.instance.getTemperature();

  /// Whether overheat condition has triggered
  bool get isTriggered => _triggered;

  /// How long we've been over threshold
  Duration get timeOverThreshold =>
      Duration(milliseconds: _consecutiveOverheatSamples * _pollInterval.inMilliseconds);

  /// Start monitoring with callback when overheat triggers
  ///
  /// [onOverheat] fires once when temp exceeds threshold for configured duration.
  /// Safe to call multiple times - restarts monitoring.
  void start({required VoidCallback onOverheat}) {
    stop();
    _triggered = false;
    _consecutiveOverheatSamples = 0;

    final threshold = ConfigService.instance.overheatThreshold;
    final triggerDuration = ConfigService.instance.overheatTriggerDuration;

    _timer = Timer.periodic(_pollInterval, (_) {
      if (_triggered) return; // Already fired

      final temp = PiIO.instance.getTemperature();
      if (temp == null) return; // No reading yet

      if (temp > threshold) {
        _consecutiveOverheatSamples++;

        final overThresholdTime = timeOverThreshold;
        if (overThresholdTime >= triggerDuration) {
          _triggered = true;
          onOverheat();
        }
      } else {
        // Temp dropped below threshold - reset counter
        _consecutiveOverheatSamples = 0;
      }
    });
  }

  /// Stop monitoring
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Reset state (for testing/recovery)
  void reset() {
    _triggered = false;
    _consecutiveOverheatSamples = 0;
  }
}

/// Callback signature for void functions
typedef VoidCallback = void Function();
