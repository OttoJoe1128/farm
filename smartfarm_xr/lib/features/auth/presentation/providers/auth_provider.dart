import 'package:flutter/foundation.dart';
import '../../data/auth_service.dart';
import '../../data/models/user_model.dart';

/// Auth durumu
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Auth State - Kimlik dogrulama durumu
class AuthState {
  final AuthStatus status;
  final UserBrief? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserBrief? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isAdmin => user?.role == 'admin';
  bool get isManagerOrAdmin =>
      user?.role == 'admin' || user?.role == 'yonetici';
}

/// Auth Provider - ChangeNotifier tabanli state yonetimi
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AuthState _state = const AuthState();

  AuthState get state => _state;

  AuthProvider() {
    checkAuthStatus();
  }

  /// Mevcut oturum durumunu kontrol et
  Future<void> checkAuthStatus() async {
    _state = _state.copyWith(status: AuthStatus.loading);
    notifyListeners();
    try {
      final bool isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final UserBrief? user = await _authService.getCurrentUser();
        if (user != null) {
          _state = AuthState(
            status: AuthStatus.authenticated,
            user: user,
          );
        } else {
          _state = const AuthState(status: AuthStatus.unauthenticated);
        }
      } else {
        _state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (err) {
      debugPrint('Auth kontrol hatasi: $err');
      _state = const AuthState(status: AuthStatus.unauthenticated);
    }
    notifyListeners();
  }

  /// Firebase ile giris
  Future<bool> loginWithFirebase(String email, String password) async {
    _state = _state.copyWith(status: AuthStatus.loading, errorMessage: null);
    notifyListeners();
    try {
      final TokenResponse response = await _authService.loginWithFirebase(email, password);
      _state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user,
      );
      notifyListeners();
      return true;
    } catch (err) {
      _state = AuthState(
        status: AuthStatus.error,
        errorMessage: _parseError(err),
      );
      notifyListeners();
      return false;
    }
  }

  /// Dogrudan giris (Firebase kullanmadan)
  Future<bool> loginDirect(String email, String password) async {
    _state = _state.copyWith(status: AuthStatus.loading, errorMessage: null);
    notifyListeners();
    try {
      final TokenResponse response = await _authService.loginDirect(email, password);
      _state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user,
      );
      notifyListeners();
      return true;
    } catch (err) {
      _state = AuthState(
        status: AuthStatus.error,
        errorMessage: _parseError(err),
      );
      notifyListeners();
      return false;
    }
  }

  /// Firebase ile kayit
  Future<bool> registerWithFirebase(
    String email,
    String password,
    String username,
    String? fullName,
  ) async {
    _state = _state.copyWith(status: AuthStatus.loading, errorMessage: null);
    notifyListeners();
    try {
      final TokenResponse response = await _authService.registerWithFirebase(
        email, password, username, fullName,
      );
      _state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user,
      );
      notifyListeners();
      return true;
    } catch (err) {
      _state = AuthState(
        status: AuthStatus.error,
        errorMessage: _parseError(err),
      );
      notifyListeners();
      return false;
    }
  }

  /// Dogrudan kayit (Firebase kullanmadan)
  Future<bool> registerDirect({
    required String username,
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    _state = _state.copyWith(status: AuthStatus.loading, errorMessage: null);
    notifyListeners();
    try {
      final TokenResponse response = await _authService.registerDirect(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      _state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user,
      );
      notifyListeners();
      return true;
    } catch (err) {
      _state = AuthState(
        status: AuthStatus.error,
        errorMessage: _parseError(err),
      );
      notifyListeners();
      return false;
    }
  }

  /// Sifre sifirlama e-postasi gonder
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (err) {
      _state = _state.copyWith(errorMessage: _parseError(err));
      notifyListeners();
      return false;
    }
  }

  /// Cikis yap
  Future<void> logout() async {
    await _authService.logout();
    _state = const AuthState(status: AuthStatus.unauthenticated);
    notifyListeners();
  }

  /// Hata mesaji temizle
  void clearError() {
    _state = _state.copyWith(errorMessage: null);
    notifyListeners();
  }

  String _parseError(dynamic error) {
    if (error is Exception) {
      final String message = error.toString();
      if (message.contains('Gecersiz e-posta veya sifre')) {
        return 'Gecersiz e-posta veya sifre';
      }
      if (message.contains('zaten kayitli') || message.contains('zaten alinmis')) {
        return 'Bu hesap zaten mevcut';
      }
      if (message.contains('deaktif')) {
        return 'Hesabiniz deaktif edilmis';
      }
      if (message.contains('wrong-password') || message.contains('user-not-found')) {
        return 'Gecersiz e-posta veya sifre';
      }
      if (message.contains('email-already-in-use')) {
        return 'Bu e-posta adresi zaten kullaniliyor';
      }
      if (message.contains('weak-password')) {
        return 'Sifre cok zayif, en az 8 karakter olmali';
      }
      if (message.contains('network')) {
        return 'Baglanti hatasi, internet baglantinizi kontrol edin';
      }
    }
    return 'Beklenmeyen bir hata olustu';
  }
}
