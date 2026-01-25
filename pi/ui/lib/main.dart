import 'package:flutter/material.dart';

import 'app_root.dart';

void main() {
  runApp(const SmartSerowApp());
}

class SmartSerowApp extends StatelessWidget {
  const SmartSerowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Serow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AppRoot(),
    );
  }
}
