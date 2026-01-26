import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Splash screen - shown during initialization
class SplashScreen extends StatelessWidget {
  final String status;

  const SplashScreen({super.key, required this.status});

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
            const SizedBox(height: 16),
            Text(
              status,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 80,
                color: theme.subdued,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
