import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/local_storage_service.dart';

class UyduGorselSonucu {
  final Uint8List imageBytes;
  final Map<String, double> overlayBounds;
  final bool onbellektenGeldi;
  final String provider;
  final DateTime? providerTarihi;
  final String freshnessStatus;

  UyduGorselSonucu({
    required this.imageBytes,
    required this.overlayBounds,
    required this.onbellektenGeldi,
    required this.provider,
    required this.providerTarihi,
    required this.freshnessStatus,
  });
}

class _UyduOnbellekKaydi {
  final UyduGorselSonucu sonuc;
  final DateTime zamanDamgasi;

  _UyduOnbellekKaydi({
    required this.sonuc,
    required this.zamanDamgasi,
  });
}

class GisService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000/api/v1',
    connectTimeout: const Duration(seconds: 10),
  ));
  final LocalStorageService _storage = const LocalStorageService();
  final Map<String, _UyduOnbellekKaydi> _uyduOnbellek =
      <String, _UyduOnbellekKaydi>{};
  static const Duration _uyduOnbellekSuresi = Duration(hours: 24);
  static const String _islemKuyruguAnahtari = 'sync_pending_ops';
  static const String _sunucuVersiyonAnahtari = 'sync_server_version';

  GisService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          String? token = AuthService.instance.accessToken;
          if ((token ?? '').isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          int? statusCode = error.response?.statusCode;
          RequestOptions requestOptions = error.requestOptions;
          bool alreadyRetried = requestOptions.extra['auth_retry'] == true;
          bool isAuthEndpoint = requestOptions.path.startsWith('/auth/');
          bool isMultipartRequest = requestOptions.data is FormData;
          if (statusCode == 401 &&
              !alreadyRetried &&
              !isAuthEndpoint &&
              !isMultipartRequest) {
            bool refreshed = await AuthService.instance.refreshSession();
            if (refreshed) {
              String? newToken = AuthService.instance.accessToken;
              RequestOptions retriedOptions = requestOptions.copyWith(
                headers: <String, dynamic>{
                  ...requestOptions.headers,
                  if ((newToken ?? '').isNotEmpty)
                    'Authorization': 'Bearer $newToken',
                },
                extra: <String, dynamic>{
                  ...requestOptions.extra,
                  'auth_retry': true,
                },
              );
              try {
                Response<dynamic> retriedResponse =
                    await _dio.fetch<dynamic>(retriedOptions);
                handler.resolve(retriedResponse);
                return;
              } catch (_) {}
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  // HATA DÜZELTİLDİ: 'Future<void>' yerine 'Future<List<dynamic>?>' yapıldı.
  Future<List<dynamic>?> haritaYukle() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['geojson', 'kml', 'json', 'shp'],
        allowMultiple: true,
      );
      if (result != null) {
        List<dynamic> tumParseller = <dynamic>[];
        for (PlatformFile secilenDosya in result.files) {
          dynamic fileData;
          if (kIsWeb) {
            fileData = secilenDosya.bytes;
          } else {
            fileData = secilenDosya.path;
          }
          if (fileData == null) {
            continue;
          }
          FormData formData = FormData.fromMap({
            "file": kIsWeb
                ? MultipartFile.fromBytes(fileData, filename: secilenDosya.name)
                : await MultipartFile.fromFile(fileData,
                    filename: secilenDosya.name),
          });
          debugPrint(
              "--- LOG: ${secilenDosya.name} sunucuya gönderiliyor... ---");
          Response<dynamic> response =
              await _dio.post('/gis/upload-map', data: formData);
          if (response.statusCode == 200 &&
              response.data != null &&
              response.data['data'] is List) {
            List<dynamic> dosyaParselleri =
                List<dynamic>.from(response.data['data'] as List<dynamic>);
            tumParseller.addAll(dosyaParselleri);
          }
        }
        if (tumParseller.isNotEmpty) {
          debugPrint(
              "--- LOG: Toplam ${tumParseller.length} parsel yüklendi ---");
          return tumParseller;
        }
      }
    } catch (e) {
      debugPrint("HATA: $e");
    }
    return null;
  }

  Future<List<dynamic>?> haritayiGetir() async {
    try {
      Response<dynamic> response = await _dio.get('/gis/snapshot');
      if (response.statusCode == 200 && response.data is Map) {
        dynamic mapRaw = response.data['map'];
        dynamic versionRaw = response.data['version'];
        if (versionRaw is num) {
          await _storage.saveString(
              _sunucuVersiyonAnahtari, versionRaw.toInt().toString());
        }
        if (mapRaw is List) {
          return List<dynamic>.from(mapRaw);
        }
      }
    } catch (e) {
      debugPrint("HARITA GETIR HATASI: $e");
    }
    return null;
  }

  Future<void> islemKuyrugunaEkle(
      String type, Map<String, dynamic> payload) async {
    List<Map<String, dynamic>> kuyruk =
        await _storage.readCollection(_islemKuyruguAnahtari);
    String simdi = DateTime.now().toUtc().toIso8601String();
    kuyruk.add(
      <String, dynamic>{
        'client_op_id': '${DateTime.now().microsecondsSinceEpoch}_$type',
        'type': type,
        'created_at': simdi,
        'timezone_offset_min': DateTime.now().timeZoneOffset.inMinutes,
        'timezone_name': DateTime.now().timeZoneName,
        'payload': payload,
      },
    );
    await _storage.writeCollection(_islemKuyruguAnahtari, kuyruk);
  }

  Future<List<dynamic>?> bekleyenIslemleriSenkronizeEt() async {
    List<Map<String, dynamic>> kuyruk =
        await _storage.readCollection(_islemKuyruguAnahtari);
    if (kuyruk.isEmpty) {
      return null;
    }
    String? versionText = await _storage.readString(_sunucuVersiyonAnahtari);
    int? baseVersion = int.tryParse(versionText ?? '');
    for (int deneme = 0; deneme < 3; deneme++) {
      try {
        Response<dynamic> response = await _dio.post(
          '/gis/sync',
          data: <String, dynamic>{
            if (baseVersion != null) 'base_version': baseVersion,
            'sync_requested_at': DateTime.now().toUtc().toIso8601String(),
            'ops': kuyruk,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
          ),
        );
        if (response.statusCode == 200 && response.data is Map) {
          String status = (response.data['status'] ?? 'ok').toString();
          dynamic versionRaw = response.data['version'];
          if (versionRaw is num) {
            await _storage.saveString(
                _sunucuVersiyonAnahtari, versionRaw.toInt().toString());
          }
          dynamic mapRaw = response.data['map'];
          if (status == 'ok') {
            await _storage.writeCollection(
                _islemKuyruguAnahtari, <Map<String, dynamic>>[]);
          }
          if (mapRaw is List) {
            return List<dynamic>.from(mapRaw);
          }
          return null;
        }
      } catch (e) {
        debugPrint("SENKRON HATASI (deneme ${deneme + 1}): $e");
        await Future<void>.delayed(
            Duration(milliseconds: 400 * (deneme + 1) * (deneme + 1)));
      }
    }
    return null;
  }

  String _uyduOnbellekAnahtariOlustur(
      List<Map<String, dynamic>> parselGeometrileri) {
    List<String> geometriImzalari = parselGeometrileri
        .map((Map<String, dynamic> geometri) =>
            jsonEncode(_siraliYapiOlustur(geometri)))
        .toList();
    geometriImzalari.sort();
    return geometriImzalari.join('|');
  }

  dynamic _siraliYapiOlustur(dynamic deger) {
    if (deger is Map) {
      List<String> anahtarlar =
          deger.keys.map((dynamic key) => key.toString()).toList()..sort();
      Map<String, dynamic> sonuc = <String, dynamic>{};
      for (String anahtar in anahtarlar) {
        sonuc[anahtar] = _siraliYapiOlustur(deger[anahtar]);
      }
      return sonuc;
    }
    if (deger is List) {
      return deger.map((dynamic oge) => _siraliYapiOlustur(oge)).toList();
    }
    return deger;
  }

  Future<UyduGorselSonucu?> uyduGorseliGetir(
      {required List<Map<String, dynamic>> parselGeometrileri,
      bool zorlaYenile = false}) async {
    try {
      String onbellekAnahtari =
          _uyduOnbellekAnahtariOlustur(parselGeometrileri);
      _UyduOnbellekKaydi? onbellekKaydi = _uyduOnbellek[onbellekAnahtari];
      bool onbellekGecerli = onbellekKaydi != null &&
          DateTime.now().difference(onbellekKaydi.zamanDamgasi) <
              _uyduOnbellekSuresi;
      if (!zorlaYenile && onbellekGecerli) {
        debugPrint("UYDU ONBELLEK: onbellekten donuyor.");
        UyduGorselSonucu onbellekSonucu = onbellekKaydi.sonuc;
        return UyduGorselSonucu(
          imageBytes: onbellekSonucu.imageBytes,
          overlayBounds: onbellekSonucu.overlayBounds,
          onbellektenGeldi: true,
          provider: onbellekSonucu.provider,
          providerTarihi: onbellekSonucu.providerTarihi,
          freshnessStatus: onbellekSonucu.freshnessStatus,
        );
      }
      Map<String, dynamic> requestBody = <String, dynamic>{
        'parcel_geometries': parselGeometrileri,
      };
      Response<dynamic> response = await _dio.post(
        '/gis/fetch-satellite-image',
        data: requestBody,
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        String? imageBase64 = response.data['image_base64'] as String?;
        if (imageBase64 == null || imageBase64.isEmpty) {
          return null;
        }
        dynamic overlayBoundsRaw = response.data['overlay_bounds'];
        if (overlayBoundsRaw is! Map) {
          return null;
        }
        Map<String, dynamic> overlayBoundsMap =
            Map<String, dynamic>.from(overlayBoundsRaw);
        Map<String, double> overlayBounds = <String, double>{
          "south": (overlayBoundsMap['south'] as num).toDouble(),
          "west": (overlayBoundsMap['west'] as num).toDouble(),
          "north": (overlayBoundsMap['north'] as num).toDouble(),
          "east": (overlayBoundsMap['east'] as num).toDouble(),
        };
        String provider =
            (response.data['imagery_provider'] ?? 'esri').toString();
        String freshnessStatus =
            (response.data['imagery_provider_freshness_status'] ?? 'unknown')
                .toString();
        DateTime? providerTarihi;
        dynamic providerTarihiRaw =
            response.data['imagery_provider_freshness_ts'];
        if (providerTarihiRaw is num) {
          providerTarihi = DateTime.fromMillisecondsSinceEpoch(
                  (providerTarihiRaw.toDouble() * 1000).round(),
                  isUtc: true)
              .toLocal();
        }
        Uint8List imageBytes = base64Decode(imageBase64);
        UyduGorselSonucu sonuc = UyduGorselSonucu(
          imageBytes: imageBytes,
          overlayBounds: overlayBounds,
          onbellektenGeldi: false,
          provider: provider,
          providerTarihi: providerTarihi,
          freshnessStatus: freshnessStatus,
        );
        _uyduOnbellek[onbellekAnahtari] = _UyduOnbellekKaydi(
          sonuc: sonuc,
          zamanDamgasi: DateTime.now(),
        );
        return sonuc;
      }
    } catch (e) {
      debugPrint("UYDU HATASI: $e");
    }
    return null;
  }

  Future<List<dynamic>?> onAnalizYap(
      {required List<Map<String, dynamic>> parselGeometrileri}) async {
    try {
      Response<dynamic> response = await _dio.post(
        '/gis/analyze-satellite',
        data: <String, dynamic>{
          'parcel_geometries': parselGeometrileri,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 20),
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        dynamic assetsRaw = response.data['assets'];
        if (assetsRaw is List) {
          return List<dynamic>.from(assetsRaw);
        }
      }
    } catch (e) {
      debugPrint("ON ANALIZ HATASI: $e");
    }
    return null;
  }

  Future<List<dynamic>?> sahaVerisiniIceriAktar({
    required List<Map<String, dynamic>> features,
    required List<Map<String, dynamic>> gpsPoints,
    Map<String, dynamic>? tkgmContext,
  }) async {
    try {
      Response<dynamic> response = await _dio.post(
        '/field/ingest',
        data: <String, dynamic>{
          'features': features,
          'gps_points': gpsPoints,
          'tkgm_context': tkgmContext ?? <String, dynamic>{},
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        dynamic mapRaw = response.data['map'];
        if (mapRaw is List) {
          return List<dynamic>.from(mapRaw);
        }
      }
    } catch (e) {
      debugPrint("SAHA INGEST HATASI: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> isEmriOlustur({
    required String assetId,
    required String title,
    String description = '',
    String assignee = '',
    String priority = 'normal',
    String? dueAt,
  }) async {
    try {
      Response<dynamic> response = await _dio.post(
        '/work-orders',
        data: <String, dynamic>{
          'asset_id': assetId,
          'title': title,
          'description': description,
          'assignee': assignee,
          'priority': priority,
          'due_at': dueAt,
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        dynamic item = response.data['item'];
        if (item is Map) {
          return item.cast<String, dynamic>();
        }
      }
    } catch (e) {
      debugPrint("IS EMRI OLUSTURMA HATASI: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> isEmirleriniGetir() async {
    try {
      Response<dynamic> response = await _dio.get('/work-orders');
      if (response.statusCode == 200 && response.data is Map) {
        dynamic itemsRaw = response.data['items'];
        if (itemsRaw is List) {
          return itemsRaw
              .whereType<Map>()
              .map((Map e) => e.cast<String, dynamic>())
              .toList();
        }
      }
    } catch (e) {
      debugPrint("IS EMIRLERI GETIRME HATASI: $e");
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> isEmriGuncelle({
    required String workOrderId,
    String? status,
    String? assignee,
    String? note,
  }) async {
    try {
      Response<dynamic> response = await _dio.patch(
        '/work-orders/$workOrderId',
        data: <String, dynamic>{
          if (status != null) 'status': status,
          if (assignee != null) 'assignee': assignee,
          if (note != null) 'note': note,
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        dynamic item = response.data['item'];
        if (item is Map) {
          return item.cast<String, dynamic>();
        }
      }
    } catch (e) {
      debugPrint("IS EMRI GUNCELLEME HATASI: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> telemetryGonder({
    required String assetId,
    required String deviceId,
    required Map<String, dynamic> metrics,
    String? measuredAt,
  }) async {
    try {
      Response<dynamic> response = await _dio.post(
        '/iot/telemetry',
        data: <String, dynamic>{
          'asset_id': assetId,
          'device_id': deviceId,
          'metrics': metrics,
          'measured_at': measuredAt,
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        return response.data.cast<String, dynamic>();
      }
    } catch (e) {
      debugPrint("TELEMETRI GONDERME HATASI: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> alarmListesiniGetir() async {
    try {
      Response<dynamic> response = await _dio.get('/iot/alerts');
      if (response.statusCode == 200 && response.data is Map) {
        dynamic itemsRaw = response.data['items'];
        if (itemsRaw is List) {
          return itemsRaw
              .whereType<Map>()
              .map((Map e) => e.cast<String, dynamic>())
              .toList();
        }
      }
    } catch (e) {
      debugPrint("ALARM LISTESI HATASI: $e");
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> kpiGetir() async {
    try {
      Response<dynamic> response = await _dio.get('/analytics/kpi');
      if (response.statusCode == 200 && response.data is Map) {
        dynamic kpi = response.data['kpi'];
        if (kpi is Map) {
          return kpi.cast<String, dynamic>();
        }
      }
    } catch (e) {
      debugPrint("KPI HATASI: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> erpSenkronBaslat(
      {String connector = 'generic'}) async {
    try {
      Response<dynamic> response = await _dio.post(
        '/integrations/erp/sync',
        data: <String, dynamic>{'connector': connector},
      );
      if (response.statusCode == 200 && response.data is Map) {
        dynamic job = response.data['job'];
        if (job is Map) {
          return job.cast<String, dynamic>();
        }
      }
    } catch (e) {
      debugPrint("ERP SENKRON HATASI: $e");
    }
    return null;
  }
}
