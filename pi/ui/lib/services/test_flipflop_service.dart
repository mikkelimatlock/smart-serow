import 'dart:async';

import 'package:flutter/widgets.dart';

import '../widgets/navigator_widget.dart';
import 'theme_service.dart';

/// Debug service that flip-flops theme and navigator emotion every 2 seconds.
///
/// Usage:
/// ```dart
/// TestFlipFlopService.instance.start(navigatorKey: _navigatorKey);
/// // Later:
/// TestFlipFlopService.instance.stop();
/// ```
class TestFlipFlopService {
  TestFlipFlopService._();
  static final instance = TestFlipFlopService._();

  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  /// Start the flip-flop cycle.
  /// Pass the navigator's GlobalKey to trigger emotion changes.
  void start({required GlobalKey<NavigatorWidgetState> navigatorKey}) {
    stop();
    _running = true;

    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      // Toggle theme
      // ThemeService.instance.toggle();

      // Surprise the navigator
      if (navigatorKey.currentState?.emotion == 'surprise') {
        navigatorKey.currentState?.reset();
      } else {
        navigatorKey.currentState?.setEmotion('surprise');
      }
    });
  }

  /// Stop the flip-flop cycle.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }
}
