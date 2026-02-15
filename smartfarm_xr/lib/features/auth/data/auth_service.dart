import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart';
import 'models/user_model.dart';
import 'auth_repository.dart';

/// Auth Service - Firebase Auth + Backend JWT islemleri
class AuthService {
  final AuthRepository _repository = AuthRepository();
  final Dio _dio;
  final firebase.FirebaseAuth _firebaseAuth = firebase.FirebaseAuth.instance;

  AuthService() : _dio = Dio(BaseOptions(
    baseUrl: _baseUrlOlustur(),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  )) {
    if (kIsWeb) {
      final BrowserHttpClientAdapter webAdapter =
          _dio.httpClientAdapter as BrowserHttpClientAdapter;
      webAdapter.withCredentials = true;
    }
    // Token interceptor: her istekte Authorization header ekle
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        final String? token = await _repository.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        // 401 hatasi: token suresi dolmus, refresh dene
        if (error.response?.statusCode == 401) {
          final bool isRefreshed = await _tryRefreshToken();
          if (isRefreshed) {
            // Yeni token ile istegi tekrar dene
            final String? newToken = await _repository.getAccessToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final Response<dynamic> response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }
        handler.next(error);
      },
    ));
  }

  static String _baseUrlOlustur() {
    if (!kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    final Uri mevcutAdres = Uri.base;
    final String host = mevcutAdres.host;
    if (host.contains('cloudworkstations.dev') && host.startsWith('8000-')) {
      return '/api/v1';
    }
    if (host == 'localhost' || host == '127.0.0.1') {
      final String currentPort = mevcutAdres.hasPort ? mevcutAdres.port.toString() : '';
      if (currentPort == '8000') {
        return '/api/v1';
      }
      return '${mevcutAdres.scheme}://$host:8000/api/v1';
    }
    if (host.contains('cloudworkstations.dev')) {
      final String newHost = host.replaceFirst(RegExp(r'^\d+-'), '8000-');
      return '${mevcutAdres.scheme}://$newHost/api/v1';
    }
    final String portKismi = mevcutAdres.hasPort ? ':${mevcutAdres.port}' : '';
    return '${mevcutAdres.scheme}://${mevcutAdres.host}$portKismi/api/v1';
  }

  /// Firebase ile giris yap ve backend JWT al
  Future<TokenResponse> loginWithFirebase(String email, String password) async {
    // Firebase'de giris yap
    final firebase.UserCredential credential = await _firebaseAuth
        .signInWithEmailAndPassword(email: email, password: password);
    final String? idToken = await credential.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Firebase token alinamadi');
    }
    // Backend'de dogrula
    final Response<dynamic> response = await _dio.post(
      '/auth/verify-firebase',
      data: {'id_token': idToken},
    );
    final TokenResponse tokenResponse = TokenResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
    await _saveTokens(tokenResponse);
    return tokenResponse;
  }

  /// Firebase ile kayit ol ve backend JWT al
  Future<TokenResponse> registerWithFirebase(
    String email,
    String password,
    String username,
    String? fullName,
  ) async {
    // Firebase'de kayit ol
    final firebase.UserCredential credential = await _firebaseAuth
        .createUserWithEmailAndPassword(email: email, password: password);
    if (fullName != null && fullName.isNotEmpty) {
      await credential.user?.updateDisplayName(fullName);
    }
    final String? idToken = await credential.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Firebase token alinamadi');
    }
    // Backend'de dogrula (otomatik kayit yapar)
    final Response<dynamic> response = await _dio.post(
      '/auth/verify-firebase',
      data: {'id_token': idToken},
    );
    final TokenResponse tokenResponse = TokenResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
    await _saveTokens(tokenResponse);
    return tokenResponse;
  }

  /// Dogrudan email/sifre ile kayit (Firebase kullanmadan)
  Future<TokenResponse> registerDirect({
    required String username,
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    final Response<dynamic> response = await _dio.post(
      '/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
      },
    );
    final TokenResponse tokenResponse = TokenResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
    await _saveTokens(tokenResponse);
    return tokenResponse;
  }

  /// Dogrudan email/sifre ile giris (Firebase kullanmadan)
  Future<TokenResponse> loginDirect(String email, String password) async {
    final Response<dynamic> response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final TokenResponse tokenResponse = TokenResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
    await _saveTokens(tokenResponse);
    return tokenResponse;
  }

  /// Firebase sifre sifirlama e-postasi gonder
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Cikis yap
  Future<void> logout() async {
    try {
      final String? refreshToken = await _repository.getRefreshToken();
      if (refreshToken != null) {
        await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
      }
    } catch (_) {
      // Logout API hatasi onemli degil, yerel temizlik yapilacak
    }
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // Firebase signout hatasi da onemli degil
    }
    await _repository.clearAll();
  }

  /// Mevcut kullanici bilgilerini getir
  Future<UserBrief?> getCurrentUser() async {
    try {
      final Response<dynamic> response = await _dio.get('/auth/me');
      return UserBrief.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Oturum acik mi kontrol et
  Future<bool> isLoggedIn() async {
    return _repository.isLoggedIn();
  }

  /// Repository'ye erisim (token okuma icin)
  AuthRepository get repository => _repository;

  Future<void> _saveTokens(TokenResponse tokenResponse) async {
    await _repository.saveAccessToken(tokenResponse.accessToken);
    await _repository.saveRefreshToken(tokenResponse.refreshToken);
    await _repository.saveUserInfo(
      userId: tokenResponse.user.id,
      role: tokenResponse.user.role,
      username: tokenResponse.user.username,
      email: tokenResponse.user.email,
    );
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final String? refreshToken = await _repository.getRefreshToken();
      if (refreshToken == null) return false;
      final Response<dynamic> response = await Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 10),
      )).post('/auth/refresh', data: {'refresh_token': refreshToken});
      final TokenResponse tokenResponse = TokenResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _saveTokens(tokenResponse);
      return true;
    } catch (_) {
      await _repository.clearAll();
      return false;
    }
  }
}
