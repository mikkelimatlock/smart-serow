import 'dart:io';
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

class NavigatorWidgetState extends State<NavigatorWidget> {
  String _emotion = 'default';

  /// Change the displayed emotion.
  /// Image file must exist at: {assetsPath}/navigator/{navigator}/{emotion}.png
  void setEmotion(String emotion) {
    if (emotion != _emotion) {
      setState(() => _emotion = emotion);
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

    return Image.file(
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
  }
}
