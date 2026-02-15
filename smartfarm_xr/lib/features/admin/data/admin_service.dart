import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models/user_model.dart';

/// Admin Service - Kullanici ve ciftlik yonetimi API islemleri
class AdminService {
  final AuthRepository _repository = AuthRepository();
  final Dio _dio;

  AdminService() : _dio = Dio(BaseOptions(
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
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        final String? token = await _repository.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
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

  /// Kullanicilari listele
  Future<Map<String, dynamic>> fetchUsers({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? role,
  }) async {
    final Map<String, dynamic> params = {
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (role != null && role.isNotEmpty) params['role'] = role;
    final Response<dynamic> response = await _dio.get('/users', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  /// Kullanici rolunu degistir
  Future<void> updateUserRole(String userId, String newRole) async {
    await _dio.put('/users/$userId/role', data: {'role': newRole});
  }

  /// Kullanici deaktive et
  Future<void> deactivateUser(String userId) async {
    await _dio.delete('/users/$userId');
  }

  /// Kullanici bilgilerini guncelle
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _dio.put('/users/$userId', data: data);
  }

  /// Ciftlikleri listele
  Future<Map<String, dynamic>> fetchFarms() async {
    final Response<dynamic> response = await _dio.get('/farms');
    return response.data as Map<String, dynamic>;
  }

  /// Ciftlik uyelerini listele
  Future<Map<String, dynamic>> fetchFarmMembers(String farmId) async {
    final Response<dynamic> response = await _dio.get('/farms/$farmId/members');
    return response.data as Map<String, dynamic>;
  }

  /// Islem gecmisini getir
  Future<Map<String, dynamic>> fetchAuditLog(String userId, {int page = 1}) async {
    final Response<dynamic> response = await _dio.get(
      '/users/$userId/audit-log',
      queryParameters: {'page': page, 'page_size': 20},
    );
    return response.data as Map<String, dynamic>;
  }
}
