import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A labeled stat display box for the dashboard
class StatBox extends StatelessWidget {
  final String label;
  final String value;

  const StatBox({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Expanded(
      flex: 1,
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 100,
              color: theme.foreground,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 80,
              color: theme.subdued,
              letterSpacing: 1,
            ),
          ),
        ],
      )
    );
  }
}
