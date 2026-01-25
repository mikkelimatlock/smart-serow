import 'package:flutter/material.dart';

import 'app_root.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SmartSerowApp());
}

class SmartSerowApp extends StatelessWidget {
  const SmartSerowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppThemeProvider(
      child: MaterialApp(
        title: 'Smart Serow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.darkSubdued,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'DIN1451',
        ),
        home: const AppRoot(),
      ),
    );
  }
}
