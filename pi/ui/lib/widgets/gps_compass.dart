import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GpsCompass extends StatelessWidget {
  final double? heading;

  const GpsCompass({super.key, this.heading});

  bool get _hasSignal => heading != null;

  String get _displayHeading {
    if (!_hasSignal) return 'N/A'; // Just make it clear; redundant anyways, this only gets called when _hasSignal
    return '${(heading! % 360).round()}'; // No need for the degree symbol
  }

  String get _compassDirection {
    if (!_hasSignal) return '';
    final directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    final index = ((heading! % 360) / 22.5).round() % 16;
    return directions[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // No signal = subdued color, valid = foreground
    final iconColour = _hasSignal ? theme.foreground : theme.highlight;

    // Convert to radians, 0 = no rotation when no signal
    final angle = _hasSignal ? (heading! * math.pi / 180.0) : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          flex: 3,
          child: Transform.rotate(
            angle: _hasSignal ? angle : 0,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Icon(
                _hasSignal ? Icons.navigation : Icons.navigation_outlined,
                size: 120,
                color: iconColour,
              ),
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              _hasSignal ? "${_displayHeading} ${_compassDirection}" : "N/A",
              style: TextStyle(
                fontSize: 80,
                color: theme.subdued,
                fontFamily: 'DIN1451',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
