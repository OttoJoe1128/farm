import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };
  // Platform error handling
  runZonedGuarded(() {
    runApp(const SmartFarmXRApp());
  }, (Object error, StackTrace stack) {
    debugPrint('Zone Error: $error');
    debugPrint('Stack trace: $stack');
  });
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
      home: Builder(
        builder: (context) {
          // Hata yakalama için try-catch
          try {
            return const DashboardPage();
          } catch (e, stack) {
            debugPrint('DashboardPage build hatası: $e');
            debugPrint('Stack: $stack');
            // Hata durumunda basit bir ekran göster
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 20),
                    Text(
                      'Hata: $e',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
