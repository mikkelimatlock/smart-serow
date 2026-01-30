import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/config_service.dart';

/// Displays the navigator character with emotion support.
///
/// Use a GlobalKey to control emotions from parent:
/// ```dart
/// final _navigatorKey = GlobalKey<NavigatorWidgetState>();
/// NavigatorWidget(key: _navigatorKey)
/// // Later:
/// _navigatorKey.currentState?.setEmotion('happy');
/// ```
class NavigatorWidget extends StatefulWidget {
  const NavigatorWidget({super.key});

  @override
  State<NavigatorWidget> createState() => NavigatorWidgetState();
}

class NavigatorWidgetState extends State<NavigatorWidget>
    with SingleTickerProviderStateMixin {
  String _emotion = 'default';
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  /// Change the displayed emotion.
  /// Image file must exist at: {assetsPath}/navigator/{navigator}/{emotion}.png
  void setEmotion(String emotion) {
    if (emotion != _emotion) {
      setState(() => _emotion = emotion);
      if (emotion == 'surprise') {
        _shakeController.forward(from: 0);
      }
    }
  }

  /// Reset to default emotion
  void reset() => setEmotion('default');

  /// Current emotion
  String get emotion => _emotion;

  @override
  Widget build(BuildContext context) {
    final config = ConfigService.instance;
    final basePath = '${config.assetsPath}/navigator/${config.navigator}';

    final image = Image.file(
      File('$basePath/$_emotion.png'),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback: try default.png if specific emotion missing
        if (_emotion != 'default') {
          return Image.file(
            File('$basePath/default.png'),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );
        }
        return const SizedBox.shrink();
      },
    );

    // Shake animation for surprise
    return AnimatedBuilder(
      animation: _shakeController,
      child: image,
      builder: (context, child) {
        final shake = sin(_shakeController.value * pi * 6) * 10 *
            (1 - _shakeController.value); // 6 oscillations, 4px amplitude, decay
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
    );
  }
}
