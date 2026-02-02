import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

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
      );

      if (result != null) {
        dynamic fileData;
        if (kIsWeb) {
          fileData = result.files.single.bytes;
        } else {
          fileData = result.files.single.path;
        }

        if (fileData == null) return null;

        FormData formData = FormData.fromMap({
          "file": kIsWeb 
              ? MultipartFile.fromBytes(fileData, filename: result.files.single.name)
              : await MultipartFile.fromFile(fileData, filename: result.files.single.name),
        });

        debugPrint("--- LOG: Sunucuya dosya gönderiliyor... ---");
        Response response = await _dio.post('/gis/upload-map', data: formData);

        if (response.statusCode == 200) {
          debugPrint("--- LOG: Sunucudan veri geldi: ${response.data['data'].length} adet ---");
          // Backend'den gelen listeyi Dashboard'a geri döndür
          return response.data['data']; 
        }
      }
    } catch (e) {
      debugPrint("HATA: $e");
    }
    return null;
  }
}
