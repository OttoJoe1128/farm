import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/pages/giris_sayfasi.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    };
    unawaited(
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).catchError(
        (Object error, StackTrace stack) {
          debugPrint('Firebase init hatası: $error');
          debugPrint('Firebase init stack: $stack');
        },
      ),
    );
    runApp(const SmartFarmXRApp());
  }, (Object error, StackTrace stack) {
    debugPrint('Zone Error: $error');
    debugPrint('Stack trace: $stack');
  });
}

/// SmartFarm XR Ana Uygulama
class SmartFarmXRApp extends StatefulWidget {
  const SmartFarmXRApp({super.key});

  @override
  State<SmartFarmXRApp> createState() => _SmartFarmXRAppState();
}

class _SmartFarmXRAppState extends State<SmartFarmXRApp> {
  final AuthProvider _authProvider = AuthProvider();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartFarm XR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ListenableBuilder(
        listenable: _authProvider,
        builder: (BuildContext context, Widget? child) {
          // Auth durumuna gore yonlendirme
          switch (_authProvider.state.status) {
            case AuthStatus.initial:
            case AuthStatus.loading:
              return _buildSplashScreen();
            case AuthStatus.authenticated:
              return _buildDashboard();
            case AuthStatus.unauthenticated:
            case AuthStatus.error:
              return GirisSayfasi(
                authProvider: _authProvider,
                onLoginSuccess: () {
                  // State degisikligi otomatik rebuild tetikleyecek
                },
              );
          }
        },
      ),
    );
  }

  Widget _buildSplashScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 64, color: Color(0xFF00D4AA)),
            SizedBox(height: 16),
            Text(
              'SmartFarm XR',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    try {
      return DashboardPage(
        authProvider: _authProvider,
      );
    } catch (e, stack) {
      debugPrint('DashboardPage build hatası: $e');
      debugPrint('Stack: $stack');
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
  }
}
