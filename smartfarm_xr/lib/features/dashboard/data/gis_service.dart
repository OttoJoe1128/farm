import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class UyduGorselSonucu {
  final Uint8List imageBytes;
  final Map<String, double> overlayBounds;

  UyduGorselSonucu({
    required this.imageBytes,
    required this.overlayBounds,
  });
}

class GisService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000/api/v1',
    connectTimeout: const Duration(seconds: 10),
  ));

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
                : await MultipartFile.fromFile(fileData, filename: secilenDosya.name),
          });
          debugPrint("--- LOG: ${secilenDosya.name} sunucuya gönderiliyor... ---");
          Response<dynamic> response = await _dio.post('/gis/upload-map', data: formData);
          if (response.statusCode == 200 && response.data != null && response.data['data'] is List) {
            List<dynamic> dosyaParselleri = List<dynamic>.from(response.data['data'] as List<dynamic>);
            tumParseller.addAll(dosyaParselleri);
          }
        }
        if (tumParseller.isNotEmpty) {
          debugPrint("--- LOG: Toplam ${tumParseller.length} parsel yüklendi ---");
          return tumParseller;
        }
      }
    } catch (e) {
      debugPrint("HATA: $e");
    }
    return null;
  }

  Future<UyduGorselSonucu?> uyduGorseliGetir({required List<Map<String, dynamic>> parselGeometrileri}) async {
    try {
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
        Map<String, dynamic> overlayBoundsMap = Map<String, dynamic>.from(overlayBoundsRaw);
        Map<String, double> overlayBounds = <String, double>{
          "south": (overlayBoundsMap['south'] as num).toDouble(),
          "west": (overlayBoundsMap['west'] as num).toDouble(),
          "north": (overlayBoundsMap['north'] as num).toDouble(),
          "east": (overlayBoundsMap['east'] as num).toDouble(),
        };
        Uint8List imageBytes = base64Decode(imageBase64);
        return UyduGorselSonucu(imageBytes: imageBytes, overlayBounds: overlayBounds);
      }
    } catch (e) {
      debugPrint("UYDU HATASI: $e");
    }
    return null;
  }
}
