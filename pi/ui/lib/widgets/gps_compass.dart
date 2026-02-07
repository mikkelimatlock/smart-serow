import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GpsCompass extends StatelessWidget {
  final double? heading;

  const GpsCompass({super.key, this.heading});

  bool get _hasSignal => heading != null && !heading!.isNaN && heading! >= 0 && heading! < 360;

  String get _displayHeading {
    if (!_hasSignal) return '—°';
    return '${heading!.round()}°';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // No signal = subdued color, valid = foreground
    final color = _hasSignal ? theme.foreground : theme.subdued;

    // Convert to radians, 0 = no rotation when no signal
    final angle = _hasSignal ? (heading! * math.pi / 180.0) : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          flex: 3,
          child: Transform.rotate(
            angle: angle,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Icon(
                Icons.navigation,
                size: 60,
                color: color,
              ),
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              _displayHeading,
              style: TextStyle(
                fontSize: 30,
                color: color,
                fontFamily: 'DIN1451',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
