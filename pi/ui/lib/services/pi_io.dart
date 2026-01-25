import 'dart:io';

/// Abstraction for Raspberry Pi hardware I/O
///
/// Uses fire-and-forget async reads with synchronous cache returns.
/// UI always gets immediate response, cache updates in background.
class PiIO {
  PiIO._() {
    // Kick off initial read
    _refreshTemperature();
  }
  static final instance = PiIO._();

  // Thermal zone file path (returns millidegrees)
  static const _thermalPath = '/sys/class/thermal/thermal_zone0/temp';

  // Cache
  double? _tempCache;
  bool _tempReadInProgress = false;

  /// Get CPU temperature in Celsius (synchronous, returns cached value)
  ///
  /// Returns immediately with cached value (or null if no read has completed).
  /// Triggers background refresh if not already in progress.
  double? getTemperature() {
    // Fire off background read if not already running
    if (!_tempReadInProgress) {
      _refreshTemperature();
    }
    return _tempCache;
  }

  /// Background read - updates cache when complete
  Future<void> _refreshTemperature() async {
    if (_tempReadInProgress) return;
    _tempReadInProgress = true;

    try {
      final file = File(_thermalPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        _tempCache = int.parse(content.trim()) / 1000.0;
      }
    } catch (e) {
      // Not on Pi, or permission issue - cache stays as-is
    } finally {
      _tempReadInProgress = false;
    }
  }

  /// Force clear cache (next getTemperature will return null until read completes)
  void clearCache() {
    _tempCache = null;
  }
}
