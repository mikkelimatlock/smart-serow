import 'dart:convert';
import 'dart:io';

/// Configuration service - loads and caches values from config.json
///
/// Uses singleton pattern. Falls back to defaults if config file missing.
class ConfigService {
  ConfigService._();
  static final instance = ConfigService._();

  // Loaded config cache
  Map<String, dynamic>? _config;
  bool _loaded = false;

  // Defaults
  static const double _defaultThreshold = 80.0;
  static const int _defaultTriggerDuration = 10;
  static const int _defaultShutdownDelay = 10;

  /// Load config from JSON file
  ///
  /// Looks for config.json in same directory as executable.
  /// Safe to call multiple times - only loads once.
  Future<void> load() async {
    if (_loaded) return;

    try {
      // Config file sits next to the executable
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent.path;
      final configPath = '$exeDir${Platform.pathSeparator}config.json';

      final file = File(configPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        _config = jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      // Config parse error - fall back to defaults
      _config = null;
    }

    _loaded = true;
  }

  /// CPU temperature threshold in Celsius
  double get overheatThreshold {
    final overheat = _config?['overheat'] as Map<String, dynamic>?;
    final value = overheat?['threshold_celsius'];
    if (value is num) return value.toDouble();
    return _defaultThreshold;
  }

  /// How long temp must exceed threshold before triggering
  Duration get overheatTriggerDuration {
    final overheat = _config?['overheat'] as Map<String, dynamic>?;
    final value = overheat?['trigger_duration_sec'];
    if (value is int) return Duration(seconds: value);
    return Duration(seconds: _defaultTriggerDuration);
  }

  /// Countdown before shutdown after overheat triggers
  Duration get shutdownDelay {
    final overheat = _config?['overheat'] as Map<String, dynamic>?;
    final value = overheat?['shutdown_delay_sec'];
    if (value is int) return Duration(seconds: value);
    return Duration(seconds: _defaultShutdownDelay);
  }
}
