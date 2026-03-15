import 'package:dio/dio.dart';
import '../utils/local_storage_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:8000/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  final LocalStorageService _storage = const LocalStorageService();

  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _userEmailKey = 'auth_user_email';
  static const String _userNameKey = 'auth_user_name';
  static const String _userRoleKey = 'auth_user_role';

  String? _accessToken;
  String? _refreshToken;
  String? _userEmail;
  String? _userName;
  String? _userRole;

  String? get accessToken => _accessToken;
  String? get userRole => _userRole;
  bool get isLoggedIn => (_accessToken ?? '').isNotEmpty;

  Future<void> initialize() async {
    _accessToken = await _storage.readString(_accessTokenKey);
    _refreshToken = await _storage.readString(_refreshTokenKey);
    _userEmail = await _storage.readString(_userEmailKey);
    _userName = await _storage.readString(_userNameKey);
    _userRole = await _storage.readString(_userRoleKey);
    if (!isLoggedIn) {
      return;
    }
    try {
      await _dio.get(
        '/auth/me',
        options: Options(headers: _authHeaders()),
      );
    } catch (_) {
      bool refreshed = await refreshSession();
      if (!refreshed) {
        await logout();
      }
    }
  }

  Map<String, dynamic> _authHeaders() {
    if ((_accessToken ?? '').isEmpty) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{'Authorization': 'Bearer $_accessToken'};
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    Response<dynamic> response = await _dio.post(
      '/auth/login',
      data: <String, dynamic>{
        'email': email.trim(),
        'password': password,
      },
    );
    return _saveAuthPayload(response.data);
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
  }) async {
    Response<dynamic> response = await _dio.post(
      '/auth/register',
      data: <String, dynamic>{
        'email': email.trim(),
        'username': username.trim(),
        'password': password,
      },
    );
    return _saveAuthPayload(response.data);
  }

  Future<bool> refreshSession() async {
    if ((_refreshToken ?? '').isEmpty) {
      return false;
    }
    try {
      Response<dynamic> response = await _dio.post(
        '/auth/refresh',
        data: <String, dynamic>{
          'refresh_token': _refreshToken,
        },
      );
      return _saveAuthPayload(response.data);
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _userEmail = null;
    _userName = null;
    _userRole = null;
    await _storage.deleteKey(_accessTokenKey);
    await _storage.deleteKey(_refreshTokenKey);
    await _storage.deleteKey(_userEmailKey);
    await _storage.deleteKey(_userNameKey);
    await _storage.deleteKey(_userRoleKey);
  }

  Future<bool> _saveAuthPayload(dynamic payload) async {
    if (payload is! Map) {
      return false;
    }
    String accessToken = (payload['access_token'] ?? '').toString();
    String refreshToken = (payload['refresh_token'] ?? '').toString();
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      return false;
    }
    Map<String, dynamic> user = Map<String, dynamic>.from(
        (payload['user'] ?? <String, dynamic>{}) as Map);
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userEmail = (user['email'] ?? '').toString();
    _userName = (user['username'] ?? '').toString();
    _userRole = (user['role'] ?? 'user').toString();
    await _storage.saveString(_accessTokenKey, _accessToken!);
    await _storage.saveString(_refreshTokenKey, _refreshToken!);
    await _storage.saveString(_userEmailKey, _userEmail ?? '');
    await _storage.saveString(_userNameKey, _userName ?? '');
    await _storage.saveString(_userRoleKey, _userRole ?? 'user');
    return true;
  }
}
