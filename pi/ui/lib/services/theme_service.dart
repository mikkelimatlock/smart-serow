/// Theme switching service - singleton pattern matching OverheatMonitor
///
/// Manages dark/bright mode state and notifies listeners on change.
/// Default is dark mode. Call setDarkMode() from sensor readings.
class ThemeService {
  ThemeService._();
  static final instance = ThemeService._();

  bool _isDarkMode = true;
  final List<void Function()> _listeners = [];

  /// Current theme mode
  bool get isDarkMode => _isDarkMode;

  /// Set theme mode. Notifies listeners if changed.
  void setDarkMode(bool dark) {
    if (_isDarkMode == dark) return;
    _isDarkMode = dark;
    _notifyListeners();
  }

  /// Toggle between dark and bright
  void toggle() => setDarkMode(!_isDarkMode);

  /// Add a listener for theme changes
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}
