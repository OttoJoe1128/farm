import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/dashboard_page.dart';

void main() {
  runApp(const SmartFarmXRApp());
}

/// SmartFarm XR Ana Uygulama
class SmartFarmXRApp extends StatelessWidget {
  const SmartFarmXRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartFarm XR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DashboardPage(),
    );
  }
}
