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
  static const String _defaultNavigator = 'rei';

  // Executable directory (for fallback paths)
  late final String _exeDir;

  /// Load config from JSON file
  ///
  /// Looks for config.json in same directory as executable.
  /// Safe to call multiple times - only loads once.
  Future<void> load() async {
    if (_loaded) return;

    // Config file sits next to the executable
    final exePath = Platform.resolvedExecutable;
    _exeDir = File(exePath).parent.path;

    try {
      final configPath = '$_exeDir${Platform.pathSeparator}config.json';

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

  /// Path to external assets directory
  String get assetsPath {
    final value = _config?['assets_path'];
    if (value is String && value.isNotEmpty) return value;
    // Fallback: assets/ next to executable
    return '$_exeDir${Platform.pathSeparator}assets';
  }

  /// Navigator character name (subfolder in assets/navigator/)
  String get navigator {
    final value = _config?['navigator'];
    if (value is String && value.isNotEmpty) return value;
    return _defaultNavigator;
  }

  /// Backend URL for API calls
  String get backendUrl {
    final value = _config?['backend_url'];
    if (value is String && value.isNotEmpty) return value;
    return 'http://127.0.0.1:5000';
  }

  /// Get list of all navigator image files
  ///
  /// Scans the navigator directory for PNG files.
  /// Returns empty list if directory doesn't exist.
  Future<List<File>> getNavigatorImages() async {
    final dir = Directory('$assetsPath${Platform.pathSeparator}navigator${Platform.pathSeparator}$navigator');
    if (!await dir.exists()) return [];

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList();
  }
}
