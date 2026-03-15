import 'package:flutter/material.dart';
import 'dart:async';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/auth/presentation/login_page.dart';

void main() {
  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Platform error handling
  runZonedGuarded(() {
    runApp(const SmartFarmXRApp());
  }, (error, stack) {
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
  bool _ready = false;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await AuthService.instance.initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _ready = true;
      _authenticated = AuthService.instance.isLoggedIn;
    });
  }

  void _handleLoginSuccess() {
    setState(() {
      _authenticated = true;
    });
  }

  Future<void> _handleLogout() async {
    await AuthService.instance.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _authenticated = false;
    });
  }

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
            if (!_ready) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (!_authenticated) {
              return LoginPage(onAuthenticated: _handleLoginSuccess);
            }
            return DashboardPage(onLogout: _handleLogout);
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
