import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'screens/loading_screen.dart';
import 'ui/theme.dart';

class BusJamApp extends StatelessWidget {
  const BusJamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoadingScreen(),
    );
  }
}
