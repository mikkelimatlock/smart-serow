import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Splash screen - shown during initialization
///
/// Displays parallel status items that independently flip to "Ready".
class SplashScreen extends StatelessWidget {
  final Map<String, String> statuses;

  const SplashScreen({super.key, required this.statuses});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terrain,
              size: 240,
              color: theme.subdued,
              // replace with custom logo later
            ),
            const SizedBox(height: 24),
            Text(
              'Smart Serow',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 160,
                color: theme.foreground,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: statuses.entries.map((entry) {
                final isReady = entry.value == 'Ready';
                return Text(
                  '${entry.key}: ${entry.value}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 48,
                    color: isReady ? theme.foreground : theme.subdued,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
