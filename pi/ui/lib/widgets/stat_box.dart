import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A labeled stat display box for the dashboard bottom row.
class StatBox extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  final int flex;

  /// Optional warning predicate - if returns true, value shows in highlight color
  final bool Function()? isWarning;

  const StatBox({
    super.key,
    required this.value,
    this.unit,
    required this.label,
    this.flex = 1,
    this.isWarning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final warning = isWarning?.call() ?? false;
    final valueColor = warning ? theme.highlight : theme.foreground;

    return Expanded(
      flex: flex,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final baseSize = constraints.maxHeight * 0.4;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Value + optional unit
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: baseSize,
                      fontWeight: FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: valueColor,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: baseSize * 0.1),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit!,
                      style: TextStyle(
                        fontSize: baseSize * 0.5,
                        fontWeight: FontWeight.w400,
                        color: theme.subdued,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: baseSize * 0.1),
              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: baseSize * 0.6,
                  fontWeight: FontWeight.w400,
                  color: theme.subdued,
                  letterSpacing: 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
