import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'widgets/harita_paneli.dart';
import 'widgets/varlik_kutuphanesi.dart';
import 'widgets/components/panel_components.dart';
import '../data/gis_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const double _dunyaYaricapiMetre = 6378137.0;
  final GisService _gisService = GisService();
  List<dynamic>? _haritaVerisi; 
  Map<String, dynamic>? _seciliParsel; 
  String? _seciliArac; 
  Key _haritaKey = UniqueKey();
  Uint8List? _uyduGorseliBytes;
  Map<String, double>? _uyduOverlaySiniri;
  bool _uyduYukleniyor = false;
  bool _varlikYonetimModuAktif = false;

  void _dosyaYukleVeCiz() async {
    List<dynamic>? gelenVeri = await _gisService.haritaYukle();
    if (!mounted) {
      return;
    }
    if (gelenVeri != null && gelenVeri.isNotEmpty) {
      setState(() {
        _haritaVerisi = gelenVeri;
        _haritaKey = UniqueKey();
        _seciliParsel = null;
        _uyduGorseliBytes = null;
        _uyduOverlaySiniri = null;
        _seciliArac = null;
        _varlikYonetimModuAktif = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parseller yüklendi. Harita otomatik odaklandı."), backgroundColor: Colors.blue));
    }
  }

  void _parselSecildi(Map<String, dynamic> parsel) {
    setState(() {
      _seciliParsel = parsel;
      _uyduGorseliBytes = null;
      _uyduOverlaySiniri = null;
      _varlikYonetimModuAktif = true;
    });
  }

  void _aracSecildi(String arac) {
    setState(() {
      if (_seciliArac == arac) {
        _seciliArac = null;
      } else {
        _seciliArac = arac;
      }
    });
  }

  void _varlikEklendi(String tip, LatLng konum) {
    debugPrint("DB KAYIT: YENİ $tip -> $konum");
    if (_haritaVerisi != null) {
      List<dynamic> guncelListe = List.from(_haritaVerisi!);
      Map<String, dynamic> lokalMetreOzellikleri = _lokalMetreOzellikleriniOlustur(konum);
      guncelListe.add({
        "name": "Yeni ${tip.toUpperCase()}",
        "type": "Point",
        "geometry": { "type": "Point", "coordinates": [konum.longitude, konum.latitude] },
        "style": {"color": "#FF0000", "icon": tip},
        "properties": {"iot_connected": false, ...lokalMetreOzellikleri}
      });
      setState(() {
        _haritaVerisi = guncelListe;
        _seciliArac = null; // Eklendikten sonra aracı bırak
      });
    }
  }

  void _varlikTasindi(int index, LatLng yeniKonum) {
    debugPrint("DB GÜNCELLEME: Index $index taşındı -> $yeniKonum");
    if (_haritaVerisi != null && index < _haritaVerisi!.length) {
      List<dynamic> guncelListe = List.from(_haritaVerisi!);
      guncelListe[index]['geometry']['coordinates'] = [yeniKonum.longitude, yeniKonum.latitude];
      Map<String, dynamic> mevcutOzellikler = Map<String, dynamic>.from((guncelListe[index]['properties'] ?? {}) as Map);
      Map<String, dynamic> lokalMetreOzellikleri = _lokalMetreOzellikleriniOlustur(yeniKonum);
      guncelListe[index]['properties'] = {...mevcutOzellikler, ...lokalMetreOzellikleri};
      setState(() => _haritaVerisi = guncelListe);
    }
  }

  void _varlikSilindi(int index) {
    debugPrint("DB SİLME: Index $index silindi");
    if (_haritaVerisi != null && index < _haritaVerisi!.length) {
      List<dynamic> guncelListe = List.from(_haritaVerisi!);
      guncelListe.removeAt(index); 
      setState(() => _haritaVerisi = guncelListe);
    }
  }

  void _genelBakisaDon() { setState(() { _seciliParsel = null; _seciliArac = null; _uyduGorseliBytes = null; _uyduOverlaySiniri = null; _varlikYonetimModuAktif = false; }); }

  List<Map<String, dynamic>> _parselGeometrileriniTopla() {
    if (_haritaVerisi == null) {
      return <Map<String, dynamic>>[];
    }
    List<Map<String, dynamic>> sonuc = <Map<String, dynamic>>[];
    for (dynamic item in _haritaVerisi!) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      dynamic geometryRaw = item['geometry'];
      if (geometryRaw is! Map) {
        continue;
      }
      Map<String, dynamic> geometry = Map<String, dynamic>.from(geometryRaw);
      String geometryType = (geometry['type'] ?? '').toString();
      if (geometryType == 'Polygon' || geometryType == 'MultiPolygon') {
        sonuc.add(geometry);
      }
    }
    return sonuc;
  }

  Future<void> _uyduyuGetir() async {
    if (_uyduYukleniyor) {
      return;
    }
    List<Map<String, dynamic>> parselGeometrileri = _parselGeometrileriniTopla();
    if (parselGeometrileri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uydu için parsel bulunamadı."), backgroundColor: Colors.redAccent));
      return;
    }
    setState(() => _uyduYukleniyor = true);
    UyduGorselSonucu? gelenUyduSonucu = await _gisService.uyduGorseliGetir(parselGeometrileri: parselGeometrileri);
    if (!mounted) {
      return;
    }
    setState(() {
      _uyduYukleniyor = false;
      _uyduGorseliBytes = gelenUyduSonucu?.imageBytes;
      _uyduOverlaySiniri = gelenUyduSonucu?.overlayBounds;
    });
    if (gelenUyduSonucu == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uydu görseli alınamadı."), backgroundColor: Colors.redAccent));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uydu görseli parsele oturtuldu."), backgroundColor: Colors.green));
  }

  List<double> _enlemBoylamiMercatoraCevir({required double enlem, required double boylam}) {
    double kirpilmisEnlem = enlem.clamp(-85.05112878, 85.05112878);
    double xMetre = _dunyaYaricapiMetre * (boylam * math.pi / 180.0);
    double yMetre = _dunyaYaricapiMetre * math.log(math.tan(math.pi / 4 + (kirpilmisEnlem * math.pi / 180.0) / 2));
    return [xMetre, yMetre];
  }

  Map<String, dynamic> _lokalMetreOzellikleriniOlustur(LatLng nokta) {
    if (_seciliParsel == null) {
      return {};
    }
    try {
      Map<String, dynamic> geometry = Map<String, dynamic>.from(_seciliParsel!['geometry'] as Map);
      List<dynamic> koordinatHalkalari = List<dynamic>.from(geometry['coordinates'] as List<dynamic>);
      if (koordinatHalkalari.isEmpty) {
        return {};
      }
      List<dynamic> disHalka = List<dynamic>.from(koordinatHalkalari[0] as List<dynamic>);
      if (disHalka.isEmpty) {
        return {};
      }
      List<dynamic> orijinNoktasi = List<dynamic>.from(disHalka[0] as List<dynamic>);
      if (orijinNoktasi.length < 2) {
        return {};
      }
      List<double> orijinMercator = _enlemBoylamiMercatoraCevir(
        enlem: (orijinNoktasi[1] as num).toDouble(),
        boylam: (orijinNoktasi[0] as num).toDouble(),
      );
      List<double> noktaMercator = _enlemBoylamiMercatoraCevir(
        enlem: nokta.latitude,
        boylam: nokta.longitude,
      );
      double lokalX = noktaMercator[0] - orijinMercator[0];
      double lokalY = noktaMercator[1] - orijinMercator[1];
      return {
        "local_x_m": double.parse(lokalX.toStringAsFixed(2)),
        "local_y_m": double.parse(lokalY.toStringAsFixed(2)),
        "local_origin": "parcel_first_vertex",
      };
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    bool editorModu = _varlikYonetimModuAktif && _haritaVerisi != null && _haritaVerisi!.isNotEmpty;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: HaritaPaneli(
              key: _haritaKey,
              dijitalIkizVerisi: _haritaVerisi,
              seciliParsel: _seciliParsel, 
              seciliArac: _seciliArac, 
              uyduGorseliBytes: _uyduGorseliBytes,
              uyduOverlaySiniri: _uyduOverlaySiniri,
              onParselSecildi: _parselSecildi,
              onVarlikEklendi: _varlikEklendi,
              onVarlikTasindi: _varlikTasindi,
              onVarlikSilindi: _varlikSilindi,
            ), 
          ),
          Positioned(
            top: 40, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (editorModu) _aksiyonButonu(Icons.arrow_back, "Genel Bakış", Colors.redAccent, _genelBakisaDon)
                    else _aksiyonButonu(Icons.upload_file, "Parsel Yükle", Colors.black54, _dosyaYukleVeCiz),
                    if (editorModu) const SizedBox(width: 8),
                    if (editorModu) _aksiyonButonu(Icons.satellite_alt, _uyduYukleniyor ? "Yükleniyor..." : "Uyduyu Getir", Colors.green.shade700, _uyduYukleniyor ? () {} : _uyduyuGetir),
                  ],
                ),
                if (editorModu)
                  GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: Text(
                        _seciliParsel != null ? _seciliParsel!['name'] : "Birleşik Çiftlik",
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
              ],
            ),
          ),
          
          if (editorModu) 
            Positioned(
              left: 0, right: 0, bottom: 0, 
              child: VarlikKutuphanesi(
                seciliArac: _seciliArac, 
                onAracSecildi: _aracSecildi
              )
            ),
          
          if (_haritaVerisi == null) Center(child: GlassContainer(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.map, size: 50, color: Colors.white54), SizedBox(height: 10), Text("Başlamak için sol üstten bir parsel dosyası yükleyin.", style: TextStyle(color: Colors.white))])))),
        ],
      ),
    );
  }
  
  Widget _aksiyonButonu(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: GlassContainer(child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), decoration: BoxDecoration(color: color.withOpacity(0.5), borderRadius: BorderRadius.circular(30)), child: Row(children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))));
  }
}
