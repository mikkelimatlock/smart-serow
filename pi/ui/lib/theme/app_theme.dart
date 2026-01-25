import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import 'app_colors.dart';

/// InheritedWidget providing runtime theme colors
///
/// Wraps the app and provides semantic color getters that resolve
/// to dark or bright variants based on ThemeService state.
///
/// Usage: AppTheme.of(context).background
class AppTheme extends InheritedWidget {
  final bool isDarkMode;

  const AppTheme({
    super.key,
    required this.isDarkMode,
    required super.child,
  });

  /// Get the nearest AppTheme from context
  static AppTheme of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    assert(theme != null, 'No AppTheme found in context');
    return theme!;
  }

  // Semantic color getters - pick dark or bright based on mode
  Color get background => isDarkMode ? AppColors.darkBackground : AppColors.brightBackground;
  Color get foreground => isDarkMode ? AppColors.darkForeground : AppColors.brightForeground;
  Color get highlight => isDarkMode ? AppColors.darkHighlight : AppColors.brightHighlight;
  Color get subdued => isDarkMode ? AppColors.darkSubdued : AppColors.brightSubdued;

  @override
  bool updateShouldNotify(AppTheme oldWidget) => isDarkMode != oldWidget.isDarkMode;
}

/// Wrapper widget that manages AppTheme state
///
/// Listens to ThemeService and rebuilds when theme changes.
/// Place this at the root of your widget tree.
class AppThemeProvider extends StatefulWidget {
  final Widget child;

  const AppThemeProvider({super.key, required this.child});

  @override
  State<AppThemeProvider> createState() => _AppThemeProviderState();
}

class _AppThemeProviderState extends State<AppThemeProvider> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme(
      isDarkMode: ThemeService.instance.isDarkMode,
      child: widget.child,
    );
  }
}
