import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Large stat display for main dashboard area.
/// Fixed-size container - content changes don't affect layout.
class StatBoxMain extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  final int flex;

  const StatBoxMain({
    super.key,
    required this.value,
    this.unit,
    required this.label,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Expanded(
      flex: flex,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Scale fonts relative to box height for consistent proportions
          final baseSize = constraints.maxHeight * 0.4;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Value + optional unit row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: baseSize,
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.foreground,
                      height: 1,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      unit!,
                      style: TextStyle(
                        fontSize: baseSize * 0.4,
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
                  fontSize: baseSize * 0.35,
                  fontWeight: FontWeight.w400,
                  color: theme.subdued,
                  letterSpacing: 2,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
