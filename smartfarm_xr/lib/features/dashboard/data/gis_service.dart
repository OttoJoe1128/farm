import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

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
  /// API base URL'ini belirler.
  /// Tek port cozumu: Frontend ve backend ayni origin'den sunuluyorsa
  /// (IDX'te 8000 portu), relative URL '/api/v1' yeterlidir.
  /// Farkli portlardaysa (localhost gelistirme) cross-origin URL olusturulur.
  static String _baseUrlOlustur() {
    if (!kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    Uri mevcutAdres = Uri.base;
    String host = mevcutAdres.host;
    // IDX tek port cozumu: 8000 portundan sunuluyorsa relative URL kullan
    if (host.contains('cloudworkstations.dev') && host.startsWith('8000-')) {
      return '/api/v1';
    }
    // Localhost: ayni porttaysa (tek port) relative, farkli portsa cross-origin
    if (host == 'localhost' || host == '127.0.0.1') {
      String currentPort = mevcutAdres.hasPort ? mevcutAdres.port.toString() : '';
      if (currentPort == '8000') {
        return '/api/v1';
      }
      return '${mevcutAdres.scheme}://$host:8000/api/v1';
    }
    // IDX 8080 portu (eski yontem, fallback)
    if (host.contains('cloudworkstations.dev')) {
      host = host.replaceFirst(RegExp(r'^\d+-'), '8000-');
      return '${mevcutAdres.scheme}://$host/api/v1';
    }
    String portKismi = mevcutAdres.hasPort ? ':${mevcutAdres.port}' : '';
    return '${mevcutAdres.scheme}://${mevcutAdres.host}$portKismi/api/v1';
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrlOlustur(),
    connectTimeout: const Duration(seconds: 10),
  ));
  final Map<String, _UyduOnbellekKaydi> _uyduOnbellek = <String, _UyduOnbellekKaydi>{};
  static const Duration _uyduOnbellekSuresi = Duration(hours: 24);
  String? _sonHata;

  String get aktifBaseUrl => _dio.options.baseUrl;
  String? get sonHata => _sonHata;

  GisService() {
    if (kIsWeb) {
      // Cross-origin isteklerde credential gonderimi (fallback icin)
      BrowserHttpClientAdapter webAdapter = _dio.httpClientAdapter as BrowserHttpClientAdapter;
      webAdapter.withCredentials = true;
    }
  }

  // HATA DÜZELTİLDİ: 'Future<void>' yerine 'Future<List<dynamic>?>' yapıldı.
  Future<List<dynamic>?> haritaYukle() async {
    _sonHata = null;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['geojson', 'kml', 'json', 'shp'],
        allowMultiple: true,
      );
      if (result == null) {
        _sonHata = "Dosya seçimi iptal edildi.";
        return null;
      }
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
              : await MultipartFile.fromFile(fileData, filename: secilenDosya.name),
        });
        debugPrint("--- LOG: ${secilenDosya.name} sunucuya gönderiliyor... ---");
        Response<dynamic> response = await _dio.post('/gis/upload-map', data: formData);
        if (response.statusCode == 200 && response.data != null && response.data['data'] is List) {
          List<dynamic> dosyaParselleri = List<dynamic>.from(response.data['data'] as List<dynamic>);
          tumParseller.addAll(dosyaParselleri);
          continue;
        }
        _sonHata = "Yükleme başarısız: durum=${response.statusCode}";
      }
      if (tumParseller.isNotEmpty) {
        debugPrint("--- LOG: Toplam ${tumParseller.length} parsel yüklendi ---");
        return tumParseller;
      }
      _sonHata ??= "Yüklenen dosyalardan parsel okunamadı.";
    } catch (e) {
      if (e is DioException) {
        String? ayrinti = e.message;
        if (e.response?.data != null) {
          ayrinti = "${e.response?.statusCode} - ${e.response?.data}";
        }
        _sonHata = "Sunucu erişim hatası: $ayrinti";
      } else {
        _sonHata = "Beklenmeyen hata: $e";
      }
      debugPrint("HATA: $e");
    }
    return null;
  }

  String _uyduOnbellekAnahtariOlustur(List<Map<String, dynamic>> parselGeometrileri) {
    List<String> geometriImzalari = parselGeometrileri
        .map((Map<String, dynamic> geometri) => jsonEncode(_siraliYapiOlustur(geometri)))
        .toList();
    geometriImzalari.sort();
    return geometriImzalari.join('|');
  }

  dynamic _siraliYapiOlustur(dynamic deger) {
    if (deger is Map) {
      List<String> anahtarlar = deger.keys.map((dynamic key) => key.toString()).toList()..sort();
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

  Future<UyduGorselSonucu?> uyduGorseliGetir({required List<Map<String, dynamic>> parselGeometrileri, bool zorlaYenile = false}) async {
    try {
      String onbellekAnahtari = _uyduOnbellekAnahtariOlustur(parselGeometrileri);
      _UyduOnbellekKaydi? onbellekKaydi = _uyduOnbellek[onbellekAnahtari];
      bool onbellekGecerli = onbellekKaydi != null &&
          DateTime.now().difference(onbellekKaydi.zamanDamgasi) < _uyduOnbellekSuresi;

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
        Map<String, dynamic> overlayBoundsMap;
        if (overlayBoundsRaw is String) {
          overlayBoundsMap = jsonDecode(overlayBoundsRaw) as Map<String, dynamic>;
        } else if (overlayBoundsRaw is Map) {
          overlayBoundsMap = Map<String, dynamic>.from(overlayBoundsRaw);
        } else {
          return null;
        }

        Map<String, double> overlayBounds = <String, double>{
          "south": (overlayBoundsMap['south'] as num).toDouble(),
          "west": (overlayBoundsMap['west'] as num).toDouble(),
          "north": (overlayBoundsMap['north'] as num).toDouble(),
          "east": (overlayBoundsMap['east'] as num).toDouble(),
        };

        String provider = (response.data['imagery_provider'] ?? 'esri').toString();
        String freshnessStatus = (response.data['imagery_provider_freshness_status'] ?? 'unknown').toString();
        DateTime? providerTarihi;
        dynamic providerTarihiRaw = response.data['imagery_provider_freshness_ts'];
        if (providerTarihiRaw is num) {
          providerTarihi = DateTime.fromMillisecondsSinceEpoch((providerTarihiRaw.toDouble() * 1000).round(), isUtc: true).toLocal();
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
}
