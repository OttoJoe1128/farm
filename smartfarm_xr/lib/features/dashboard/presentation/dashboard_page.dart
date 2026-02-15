import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'widgets/harita_paneli.dart';
import 'widgets/varlik_kutuphanesi.dart';
import 'widgets/components/panel_components.dart';
import '../data/gis_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/pages/profil_sayfasi.dart';

class DashboardPage extends StatefulWidget {
  final AuthProvider? authProvider;

  const DashboardPage({super.key, this.authProvider});

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
  bool _uyduOnbellekten = false;
  String _uyduSaglayici = "-";
  DateTime? _uyduSaglayiciTarihi;
  String _uyduSaglayiciTazelikDurumu = "unknown";

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
        _uyduOnbellekten = false;
        _uyduSaglayici = "-";
        _uyduSaglayiciTarihi = null;
        _uyduSaglayiciTazelikDurumu = "unknown";
        _seciliArac = null;
        _varlikYonetimModuAktif = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parseller yüklendi. Harita otomatik odaklandı."), backgroundColor: Colors.blue));
      _uyduyuGetir(sessizCalis: true);
      return;
    }
    String hataMesaji = _gisService.sonHata ?? "Parsel yükleme başarısız.";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$hataMesaji\nAPI: ${_gisService.aktifBaseUrl}"),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _parselSecildi(Map<String, dynamic> parsel) {
    setState(() {
      _seciliParsel = parsel;
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
      Map<String, dynamic> yeniVarlik = {
        "name": "Yeni ${tip.toUpperCase()}",
        "type": "Point",
        "geometry": { "type": "Point", "coordinates": [konum.longitude, konum.latitude] },
        "style": {"color": "#FF0000", "icon": tip},
        "properties": {"iot_connected": false, ...lokalMetreOzellikleri}
      };
      guncelListe.add(yeniVarlik);
      setState(() {
        _haritaVerisi = guncelListe;
        // Arac secili kalsin - surekli ekleme modu (araciniza tekrar tiklayin birakma icin)
      });
      // Backend'e kaydet
      _gisService.varlikEkle(yeniVarlik);
    }
  }

  void _varlikGuncellendi(Map<String, dynamic> guncellenmisVeri) {
    if (_haritaVerisi == null) return;
    int index = -1;
    for (int i = 0; i < _haritaVerisi!.length; i++) {
      if (identical(_haritaVerisi![i], guncellenmisVeri)) {
        index = i;
        break;
      }
    }
    if (index == -1) {
      // identical ile bulamazsa, koordinat eslesmesi dene
      for (int i = 0; i < _haritaVerisi!.length; i++) {
        dynamic item = _haritaVerisi![i];
        if (item is Map<String, dynamic> &&
            item['geometry']?['type'] == 'Point' &&
            guncellenmisVeri['geometry']?['type'] == 'Point') {
          List<dynamic>? c1 = item['geometry']?['coordinates'] as List<dynamic>?;
          List<dynamic>? c2 = guncellenmisVeri['geometry']?['coordinates'] as List<dynamic>?;
          if (c1 != null && c2 != null && c1.length >= 2 && c2.length >= 2 &&
              (c1[0] as num).toDouble() == (c2[0] as num).toDouble() &&
              (c1[1] as num).toDouble() == (c2[1] as num).toDouble()) {
            index = i;
            break;
          }
        }
      }
    }
    setState(() {
      if (index >= 0) {
        _haritaVerisi![index] = guncellenmisVeri;
      }
      _haritaKey = UniqueKey();
    });
    if (index >= 0) {
      _gisService.varlikGuncelle(index, guncellenmisVeri);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Varlık güncellendi."), backgroundColor: Colors.green));
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
      _gisService.varlikGuncelle(index, Map<String, dynamic>.from(guncelListe[index] as Map));
    }
  }

  void _varlikSilindi(int index) {
    debugPrint("DB SİLME: Index $index silindi");
    if (_haritaVerisi != null && index < _haritaVerisi!.length) {
      List<dynamic> guncelListe = List.from(_haritaVerisi!);
      guncelListe.removeAt(index); 
      setState(() => _haritaVerisi = guncelListe);
      _gisService.varlikSil(index);
    }
  }

  void _genelBakisaDon() { setState(() { _seciliParsel = null; _seciliArac = null; _uyduGorseliBytes = null; _uyduOverlaySiniri = null; _varlikYonetimModuAktif = false; _uyduOnbellekten = false; _uyduSaglayici = "-"; _uyduSaglayiciTarihi = null; _uyduSaglayiciTazelikDurumu = "unknown"; }); }

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

  Future<void> _uyduyuGetir({bool sessizCalis = false, bool zorlaYenile = false}) async {
    if (_uyduYukleniyor) {
      return;
    }
    List<Map<String, dynamic>> parselGeometrileri = _parselGeometrileriniTopla();
    if (parselGeometrileri.isEmpty) {
      if (!sessizCalis) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uydu için parsel bulunamadı."), backgroundColor: Colors.redAccent));
      }
      return;
    }
    setState(() => _uyduYukleniyor = true);
    UyduGorselSonucu? gelenUyduSonucu = await _gisService.uyduGorseliGetir(parselGeometrileri: parselGeometrileri, zorlaYenile: zorlaYenile);
    if (!mounted) {
      return;
    }
    setState(() {
      _uyduYukleniyor = false;
      _uyduGorseliBytes = gelenUyduSonucu?.imageBytes;
      _uyduOverlaySiniri = gelenUyduSonucu?.overlayBounds;
      _uyduOnbellekten = gelenUyduSonucu?.onbellektenGeldi ?? false;
      _uyduSaglayici = gelenUyduSonucu?.provider ?? "-";
      _uyduSaglayiciTarihi = gelenUyduSonucu?.providerTarihi;
      _uyduSaglayiciTazelikDurumu = gelenUyduSonucu?.freshnessStatus ?? "unknown";
    });
    if (gelenUyduSonucu == null) {
      if (!sessizCalis) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uydu görseli alınamadı."), backgroundColor: Colors.redAccent));
      }
      return;
    }
    if (!sessizCalis) {
      String bilgiMetni = gelenUyduSonucu.onbellektenGeldi
          ? "Uydu görseli onbellekten yüklendi."
          : "Uydu görseli canlı çekilip parsele oturtuldu.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bilgiMetni), backgroundColor: Colors.green));
    }
  }

  List<double> _enlemBoylamiMercatoraCevir({required double enlem, required double boylam}) {
    double kirpilmisEnlem = enlem.clamp(-85.05112878, 85.05112878);
    double xMetre = _dunyaYaricapiMetre * (boylam * math.pi / 180.0);
    double yMetre = _dunyaYaricapiMetre * math.log(math.tan(math.pi / 4 + (kirpilmisEnlem * math.pi / 180.0) / 2));
    return [xMetre, yMetre];
  }

  // --- FAZ 3: TOPLU VARLIK ICE AKTARMA ---
  bool _varlikYukleniyor = false;
  void _varlikDosyasiYukle() async {
    setState(() => _varlikYukleniyor = true);
    List<dynamic>? gelenVarliklar = await _gisService.varlikDosyasiYukle();
    if (!mounted) return;
    setState(() => _varlikYukleniyor = false);
    if (gelenVarliklar != null && gelenVarliklar.isNotEmpty) {
      setState(() {
        _haritaVerisi = [...?_haritaVerisi, ...gelenVarliklar];
        _haritaKey = UniqueKey();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${gelenVarliklar.length} varlık başarıyla yüklendi."), backgroundColor: Colors.green));
      return;
    }
    String hataMesaji = _gisService.sonHata ?? "Varlık yükleme başarısız.";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hataMesaji), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4)));
  }

  // --- FAZ 4: AI ANALIZ ---
  bool _aiTaraniyor = false;
  void _aiTaramaBaslat() async {
    List<Map<String, dynamic>> parselGeometrileri = _parselGeometrileriniTopla();
    if (parselGeometrileri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI tarama için parsel bulunamadı."), backgroundColor: Colors.redAccent));
      return;
    }
    setState(() => _aiTaraniyor = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI taraması başlatıldı... Bu biraz sürebilir."), backgroundColor: Colors.blue));
    List<dynamic>? tespiEdilenvVarliklar = await _gisService.aiAnaliz(parselGeometrileri: parselGeometrileri);
    if (!mounted) return;
    setState(() => _aiTaraniyor = false);
    if (tespiEdilenvVarliklar != null && tespiEdilenvVarliklar.isNotEmpty) {
      setState(() {
        _haritaVerisi = [...?_haritaVerisi, ...tespiEdilenvVarliklar];
        _haritaKey = UniqueKey();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI: ${tespiEdilenvVarliklar.length} varlık tespit edildi."), backgroundColor: Colors.green));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI taraması sonuç bulamadı veya hata oluştu."), backgroundColor: Colors.orangeAccent));
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
              onVarlikGuncellendi: _varlikGuncellendi,
            ), 
          ),
          Positioned(
            top: 40, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (editorModu) _aksiyonButonu(Icons.arrow_back, "Genel Bakış", Colors.redAccent, _genelBakisaDon)
                    else _aksiyonButonu(Icons.upload_file, "Parsel Yükle", Colors.black54, _dosyaYukleVeCiz),
                    if (editorModu) _aksiyonButonu(Icons.satellite_alt, _uyduYukleniyor ? "Yükleniyor..." : "Uyduyu Getir", Colors.green.shade700, _uyduYukleniyor ? () {} : () => _uyduyuGetir(), onLongPress: _uyduYukleniyor ? null : () => _uyduyuGetir(zorlaYenile: true)),
                    if (editorModu) _aksiyonButonu(Icons.playlist_add, _varlikYukleniyor ? "Yükleniyor..." : "Varlık Yükle", Colors.orange.shade700, _varlikYukleniyor ? () {} : _varlikDosyasiYukle),
                    if (editorModu) _aksiyonButonu(Icons.auto_fix_high, _aiTaraniyor ? "Taranıyor..." : "AI Tara", Colors.purple.shade700, _aiTaraniyor ? () {} : _aiTaramaBaslat),
                  ],
                ),
                if (editorModu)
                  GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: Text(
                        _seciliParsel != null ? _seciliParsel!['name'] : (_uyduOnbellekten ? "Birleşik Çiftlik • Uydu: Önbellek" : "Birleşik Çiftlik • Uydu: Canlı"),
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
              ],
            ),
          ),
          // Kullanici profil butonu (sag ust)
          if (widget.authProvider != null)
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext ctx) =>
                          _buildProfilSayfasi(),
                    ),
                  );
                },
                child: GlassContainer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.deepPurple.withValues(alpha: 0.5),
                          child: Text(
                            (widget.authProvider!.state.user?.fullName ??
                                    widget.authProvider!.state.user?.username ??
                                    '?')[0]
                                .toUpperCase(),
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.authProvider!.state.user?.username ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (editorModu && _uyduSaglayici != "-")
            Positioned(
              top: 92,
              left: 20,
              child: GlassContainer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    _uyduSaglayiciTarihi == null
                        ? "Kaynak: ${_uyduSaglayici.toUpperCase()} • Tarih: Bilinmiyor ($_uyduSaglayiciTazelikDurumu)"
                        : "Kaynak: ${_uyduSaglayici.toUpperCase()} • ${_uyduSaglayiciTarihi!.day.toString().padLeft(2, '0')}.${_uyduSaglayiciTarihi!.month.toString().padLeft(2, '0')}.${_uyduSaglayiciTarihi!.year}",
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
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
          
          if (_haritaVerisi == null) const Center(child: GlassContainer(child: Padding(padding: EdgeInsets.all(20.0), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.map, size: 50, color: Colors.white54), SizedBox(height: 10), Text("Başlamak için sol üstten bir parsel dosyası yükleyin.", style: TextStyle(color: Colors.white))])))),
        ],
      ),
    );
  }
  
  Widget _buildProfilSayfasi() {
    return ProfilSayfasi(
      authProvider: widget.authProvider!,
      onLogout: () {
        // Ana sayfaya geri don (auth state degisikligi ile login sayfasina yonlendirilecek)
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      },
    );
  }

  Widget _aksiyonButonu(IconData icon, String label, Color color, VoidCallback onTap, {VoidCallback? onLongPress}) {
    return GestureDetector(onTap: onTap, onLongPress: onLongPress, child: GlassContainer(child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), decoration: BoxDecoration(color: color.withOpacity(0.5), borderRadius: BorderRadius.circular(30)), child: Row(children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))));
  }
}
