import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';
import 'widgets/harita_paneli.dart';
import 'widgets/varlik_kutuphanesi.dart';
import 'widgets/components/panel_components.dart';
import '../data/gis_service.dart';
import '../data/farm_repository_impl.dart';
import '../domain/repositories/farm_repository.dart';
import '../../../core/utils/local_storage_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/live_event_service.dart';

class DashboardPage extends StatefulWidget {
  final Future<void> Function()? onLogout;

  const DashboardPage({super.key, this.onLogout});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const double _dunyaYaricapiMetre = 6378137.0;
  final GisService _gisService = GisService();
  late final FarmRepository _farmRepository;
  final LiveEventService _liveEventService = LiveEventService();
  final LocalStorageService _localStorage = const LocalStorageService();
  static const String _haritaVeriAnahtari = 'resume_harita_verisi';
  static const String _seciliParselAnahtari = 'resume_secili_parsel_adi';
  static const String _mapLatAnahtari = 'resume_map_center_lat';
  static const String _mapLngAnahtari = 'resume_map_center_lng';
  static const String _mapZoomAnahtari = 'resume_map_zoom';
  static const String _sonKayitZamaniAnahtari = 'resume_last_saved_at';
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
  LatLng? _kayitliMerkez;
  double? _kayitliZoom;
  Timer? _kaydetmeGecikmesi;
  StreamSubscription<Map<String, dynamic>>? _liveEventSubscription;
  Map<String, dynamic>? _kpi;
  int _alarmSayisi = 0;

  @override
  void initState() {
    super.initState();
    _farmRepository = FarmRepositoryImpl(_gisService);
    _canliAkisaBaglan();
    _oturumuHazirla();
  }

  @override
  void dispose() {
    _kaydetmeGecikmesi?.cancel();
    _liveEventSubscription?.cancel();
    _liveEventService.kapat();
    super.dispose();
  }

  Future<void> _oturumuHazirla() async {
    await _yereldenDevamDurumunuYukle();
    await _senkronizasyonuCalistir();
    await _kpiYenile();
    await _alarmSayisiniYenile();
  }

  Future<void> _yereldenDevamDurumunuYukle() async {
    List<Map<String, dynamic>> kayitliVeri =
        await _localStorage.readCollection(_haritaVeriAnahtari);
    String? seciliParselAdi =
        await _localStorage.readString(_seciliParselAnahtari);
    String? latText = await _localStorage.readString(_mapLatAnahtari);
    String? lngText = await _localStorage.readString(_mapLngAnahtari);
    String? zoomText = await _localStorage.readString(_mapZoomAnahtari);
    if (!mounted) {
      return;
    }
    setState(() {
      if (kayitliVeri.isNotEmpty) {
        _haritaVerisi = _haritaVerisiniZamanla(List<dynamic>.from(kayitliVeri));
        _varlikYonetimModuAktif = true;
      }
      if (latText != null && lngText != null && zoomText != null) {
        double? lat = double.tryParse(latText);
        double? lng = double.tryParse(lngText);
        double? zoom = double.tryParse(zoomText);
        if (lat != null && lng != null && zoom != null) {
          _kayitliMerkez = LatLng(lat, lng);
          _kayitliZoom = zoom;
        }
      }
      if (seciliParselAdi != null && _haritaVerisi != null) {
        for (dynamic item in _haritaVerisi!) {
          if (item is Map<String, dynamic> &&
              (item['name'] ?? '').toString() == seciliParselAdi) {
            _seciliParsel = item;
            break;
          }
        }
      }
      _haritaKey = UniqueKey();
    });
  }

  Future<void> _senkronizasyonuCalistir() async {
    if (_haritaVerisi != null && _haritaVerisi!.isNotEmpty) {
      await _gisService.islemKuyrugunaEkle(
        'replace_snapshot',
        <String, dynamic>{'map': _haritaVerisi},
      );
    }
    List<dynamic>? senkronSonucu =
        await _gisService.bekleyenIslemleriSenkronizeEt();
    if (senkronSonucu != null && mounted) {
      setState(() {
        _haritaVerisi = _haritaVerisiniZamanla(List<dynamic>.from(senkronSonucu));
        _varlikYonetimModuAktif = true;
        _haritaKey = UniqueKey();
      });
      await _yerelDurumuKaydet();
    }
    List<dynamic>? sunucuVerisi = await _gisService.haritayiGetir();
    if (sunucuVerisi != null && sunucuVerisi.isNotEmpty && mounted) {
      setState(() {
        _haritaVerisi = _haritaVerisiniZamanla(List<dynamic>.from(sunucuVerisi));
        _varlikYonetimModuAktif = true;
        _haritaKey = UniqueKey();
      });
      await _yerelDurumuKaydet();
    }
    await _kpiYenile();
    await _alarmSayisiniYenile();
    if (_parselGeometrileriniTopla().isNotEmpty) {
      _uyduyuGetir(sessizCalis: true);
    }
  }

  Future<void> _yerelDurumuKaydet() async {
    List<Map<String, dynamic>> yazilacak = <Map<String, dynamic>>[];
    if (_haritaVerisi != null) {
      for (dynamic item in _haritaVerisi!) {
        if (item is Map<String, dynamic>) {
          yazilacak.add(Map<String, dynamic>.from(item));
        }
      }
    }
    await _localStorage.writeCollection(_haritaVeriAnahtari, yazilacak);
    await _localStorage.saveString(
        _seciliParselAnahtari, (_seciliParsel?['name'] ?? '').toString());
    if (_kayitliMerkez != null && _kayitliZoom != null) {
      await _localStorage.saveString(
          _mapLatAnahtari, _kayitliMerkez!.latitude.toString());
      await _localStorage.saveString(
          _mapLngAnahtari, _kayitliMerkez!.longitude.toString());
      await _localStorage.saveString(
          _mapZoomAnahtari, _kayitliZoom!.toString());
    }
    await _localStorage.saveString(_sonKayitZamaniAnahtari, _simdiIso());
  }

  void _kameraDegisti(LatLng merkez, double zoom) {
    _kayitliMerkez = merkez;
    _kayitliZoom = zoom;
    _kaydetmeGecikmesi?.cancel();
    _kaydetmeGecikmesi = Timer(const Duration(milliseconds: 700), () {
      _yerelDurumuKaydet();
    });
  }

  void _dosyaYukleVeCiz() async {
    List<dynamic>? gelenVeri = await _gisService.haritaYukle();
    if (!mounted) {
      return;
    }
    if (gelenVeri != null && gelenVeri.isNotEmpty) {
      setState(() {
        _haritaVerisi = _haritaVerisiniZamanla(gelenVeri);
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
      await _yerelDurumuKaydet();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Parseller yüklendi. Harita otomatik odaklandı."),
          backgroundColor: Colors.blue));
      _uyduyuGetir(sessizCalis: true);
    }
  }

  void _parselSecildi(Map<String, dynamic> parsel) {
    setState(() {
      _seciliParsel = parsel;
      _varlikYonetimModuAktif = true;
    });
    _yerelDurumuKaydet();
  }

  void _aracSecildi(String arac) {
    setState(() {
      if (_seciliArac == arac) {
        _seciliArac = null;
      } else {
        _seciliArac = arac;
      }
    });
    _yerelDurumuKaydet();
  }

  void _varlikEklendi(String tip, LatLng konum) {
    debugPrint("DB KAYIT: YENİ $tip -> $konum");
    if (_haritaVerisi != null) {
      List<dynamic> guncelListe = List.from(_haritaVerisi!);
      Map<String, dynamic> lokalMetreOzellikleri =
          _lokalMetreOzellikleriniOlustur(konum);
      Map<String, dynamic> yeniVarlik = {
        "name": "Yeni ${tip.toUpperCase()}",
        "type": "Point",
        "geometry": {
          "type": "Point",
          "coordinates": [konum.longitude, konum.latitude]
        },
        "style": {"color": "#FF0000", "icon": tip},
        "properties": {
          "iot_connected": false,
          ...lokalMetreOzellikleri,
        }
      };
      yeniVarlik = _varlikKayitZamaniDamgasiEkle(
          yeniVarlik, islemTuru: 'asset_created');
      String assetId = _assetIdGetir(yeniVarlik);
      guncelListe.add(yeniVarlik);
      setState(() {
        _haritaVerisi = guncelListe;
        // Araci aktif tut: kullanici ayni turde ardi ardina varlik ekleyebilsin.
        // Bitirmek icin ayni araca tekrar dokunmasi yeterli.
      });
      _gisService.islemKuyrugunaEkle(
          'add_asset', <String, dynamic>{'asset_id': assetId, 'asset': yeniVarlik});
      _gisService.bekleyenIslemleriSenkronizeEt();
      _yerelDurumuKaydet();
      _kpiYenile();
    }
  }

  void _varlikTasindi(int index, LatLng yeniKonum) {
    debugPrint("DB GÜNCELLEME: Index $index taşındı -> $yeniKonum");
    if (_haritaVerisi != null && index < _haritaVerisi!.length) {
      List<dynamic> guncelListe = List.from(_haritaVerisi!);
      guncelListe[index]['geometry']
          ['coordinates'] = [yeniKonum.longitude, yeniKonum.latitude];
      Map<String, dynamic> mevcutOzellikler = Map<String, dynamic>.from(
          (guncelListe[index]['properties'] ?? {}) as Map);
      Map<String, dynamic> lokalMetreOzellikleri =
          _lokalMetreOzellikleriniOlustur(yeniKonum);
      guncelListe[index]
          ['properties'] = {...mevcutOzellikler, ...lokalMetreOzellikleri};
      guncelListe[index] = _varlikKayitZamaniDamgasiEkle(
        Map<String, dynamic>.from(guncelListe[index] as Map),
        islemTuru: 'asset_moved',
      );
      setState(() => _haritaVerisi = guncelListe);
      String assetId = _assetIdGetir(guncelListe[index]);
      _gisService.islemKuyrugunaEkle(
        'update_asset',
        <String, dynamic>{
          'index': index,
          'asset_id': assetId,
          'asset': Map<String, dynamic>.from(guncelListe[index] as Map),
        },
      );
      _gisService.bekleyenIslemleriSenkronizeEt();
      _yerelDurumuKaydet();
      _kpiYenile();
    }
  }

  void _varlikGuncellendi(int index, Map<String, dynamic> guncelVarlik) {
    if (_haritaVerisi == null || index < 0 || index >= _haritaVerisi!.length) {
      return;
    }
    List<dynamic> guncelListe = List<dynamic>.from(_haritaVerisi!);
    Map<String, dynamic> zamanlanmisVarlik = _varlikKayitZamaniDamgasiEkle(
      Map<String, dynamic>.from(guncelVarlik),
      islemTuru: 'digital_card_updated',
    );
    guncelListe[index] = zamanlanmisVarlik;
    setState(() => _haritaVerisi = guncelListe);
    String assetId = _assetIdGetir(zamanlanmisVarlik);
    _gisService.islemKuyrugunaEkle(
      'update_asset',
      <String, dynamic>{
        'index': index,
        'asset_id': assetId,
        'asset': Map<String, dynamic>.from(zamanlanmisVarlik),
      },
    );
    _gisService.bekleyenIslemleriSenkronizeEt();
    _yerelDurumuKaydet();
    _kpiYenile();
  }

  void _varlikSilindi(int index) {
    debugPrint("DB SİLME: Index $index silindi");
    if (_haritaVerisi != null && index < _haritaVerisi!.length) {
      List<dynamic> guncelListe = List.from(_haritaVerisi!);
      dynamic silinenVarlik = guncelListe[index];
      guncelListe.removeAt(index);
      setState(() => _haritaVerisi = guncelListe);
      _gisService.islemKuyrugunaEkle(
        'delete_asset',
        <String, dynamic>{
          'index': index,
          'asset_id': _assetIdGetir(silinenVarlik),
          'deleted_at': _simdiIso(),
          'deleted_asset_name': silinenVarlik is Map
              ? (silinenVarlik['name'] ?? '').toString()
              : '',
        },
      );
      _gisService.bekleyenIslemleriSenkronizeEt();
      _yerelDurumuKaydet();
      _kpiYenile();
    }
  }

  void _tumVarliklariSil() {
    if (_haritaVerisi == null) {
      return;
    }
    List<dynamic> yalnizParseller = <dynamic>[];
    for (dynamic item in _haritaVerisi!) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      Map<String, dynamic> geometry = Map<String, dynamic>.from(
          (item['geometry'] ?? <String, dynamic>{}) as Map);
      String geometryType = (geometry['type'] ?? '').toString();
      bool isAssetPolygon =
          ((item['properties']?['asset_type'] ?? '').toString() ==
              'yapi_polygon');
      if (!isAssetPolygon &&
          (geometryType == 'Polygon' || geometryType == 'MultiPolygon')) {
        yalnizParseller.add(item);
      }
    }
    setState(() {
      _haritaVerisi = yalnizParseller;
      _haritaKey = UniqueKey();
    });
    _gisService.islemKuyrugunaEkle(
      'replace_snapshot',
      <String, dynamic>{
        'map': yalnizParseller,
        'bulk_deleted_at': _simdiIso(),
      },
    );
    _gisService.bekleyenIslemleriSenkronizeEt();
    _yerelDurumuKaydet();
    _kpiYenile();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Tüm varlıklar temizlendi."),
      backgroundColor: Colors.orange,
    ));
  }

  void _genelBakisaDon() {
    setState(() {
      _seciliParsel = null;
      _seciliArac = null;
      _uyduGorseliBytes = null;
      _uyduOverlaySiniri = null;
      _varlikYonetimModuAktif = false;
      _uyduOnbellekten = false;
      _uyduSaglayici = "-";
      _uyduSaglayiciTarihi = null;
      _uyduSaglayiciTazelikDurumu = "unknown";
    });
    _yerelDurumuKaydet();
  }

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
      bool isAssetPolygon =
          ((item['properties']?['asset_type'] ?? '').toString() ==
              'yapi_polygon');
      if (!isAssetPolygon &&
          (geometryType == 'Polygon' || geometryType == 'MultiPolygon')) {
        sonuc.add(geometry);
      }
    }
    return sonuc;
  }

  Future<void> _uyduyuGetir(
      {bool sessizCalis = false, bool zorlaYenile = false}) async {
    if (_uyduYukleniyor) {
      return;
    }
    List<Map<String, dynamic>> parselGeometrileri =
        _parselGeometrileriniTopla();
    if (parselGeometrileri.isEmpty) {
      if (!sessizCalis) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Uydu için parsel bulunamadı."),
            backgroundColor: Colors.redAccent));
      }
      return;
    }
    setState(() => _uyduYukleniyor = true);
    UyduGorselSonucu? gelenUyduSonucu = await _gisService.uyduGorseliGetir(
        parselGeometrileri: parselGeometrileri, zorlaYenile: zorlaYenile);
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
      _uyduSaglayiciTazelikDurumu =
          gelenUyduSonucu?.freshnessStatus ?? "unknown";
    });
    if (gelenUyduSonucu == null) {
      if (!sessizCalis) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Uydu görseli alınamadı."),
            backgroundColor: Colors.redAccent));
      }
      return;
    }
    if (!sessizCalis) {
      String bilgiMetni = gelenUyduSonucu.onbellektenGeldi
          ? "Uydu görseli onbellekten yüklendi."
          : "Uydu görseli canlı çekilip parsele oturtuldu.";
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bilgiMetni), backgroundColor: Colors.green));
    }
  }

  List<double> _enlemBoylamiMercatoraCevir(
      {required double enlem, required double boylam}) {
    double kirpilmisEnlem = enlem.clamp(-85.05112878, 85.05112878);
    double xMetre = _dunyaYaricapiMetre * (boylam * math.pi / 180.0);
    double yMetre = _dunyaYaricapiMetre *
        math.log(
            math.tan(math.pi / 4 + (kirpilmisEnlem * math.pi / 180.0) / 2));
    return [xMetre, yMetre];
  }

  Map<String, dynamic> _lokalMetreOzellikleriniOlustur(LatLng nokta) {
    if (_seciliParsel == null) {
      return {};
    }
    try {
      Map<String, dynamic> geometry =
          Map<String, dynamic>.from(_seciliParsel!['geometry'] as Map);
      List<dynamic> koordinatHalkalari =
          List<dynamic>.from(geometry['coordinates'] as List<dynamic>);
      if (koordinatHalkalari.isEmpty) {
        return {};
      }
      List<dynamic> disHalka =
          List<dynamic>.from(koordinatHalkalari[0] as List<dynamic>);
      if (disHalka.isEmpty) {
        return {};
      }
      List<dynamic> orijinNoktasi =
          List<dynamic>.from(disHalka[0] as List<dynamic>);
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

  Future<void> _cikisYap() async {
    await widget.onLogout?.call();
    await _localStorage.deleteKey(_haritaVeriAnahtari);
    await _localStorage.deleteKey(_seciliParselAnahtari);
    await _localStorage.deleteKey(_mapLatAnahtari);
    await _localStorage.deleteKey(_mapLngAnahtari);
    await _localStorage.deleteKey(_mapZoomAnahtari);
    await _localStorage.deleteKey(_sonKayitZamaniAnahtari);
    await AuthService.instance.logout();
  }

  String _simdiIso() {
    return DateTime.now().toUtc().toIso8601String();
  }

  void _canliAkisaBaglan() {
    _liveEventSubscription = _liveEventService.baglan().listen((event) {
      if (!mounted) {
        return;
      }
      String tip = (event['type'] ?? '').toString();
      if (tip == 'telemetry') {
        List<dynamic>? alertsRaw = event['alerts'] as List<dynamic>?;
        int yeniAlarmSayisi = alertsRaw?.length ?? 0;
        if (yeniAlarmSayisi > 0) {
          setState(() {
            _alarmSayisi = _alarmSayisi + yeniAlarmSayisi;
          });
        }
        _kpiYenile();
      }
    });
  }

  String _assetIdGetir(dynamic rawItem) {
    Map<String, dynamic> item = _mapOku(rawItem);
    Map<String, dynamic> properties = _mapOku(item['properties']);
    Map<String, dynamic> meta = _mapOku(properties['meta']);
    String mevcut = (item['asset_id'] ??
            properties['asset_id'] ??
            meta['asset_id'] ??
            '')
        .toString();
    if (mevcut.isNotEmpty) {
      return mevcut;
    }
    String yeniId = '${DateTime.now().microsecondsSinceEpoch}_${item.hashCode}';
    meta['asset_id'] = yeniId;
    properties['asset_id'] = yeniId;
    properties['meta'] = meta;
    item['asset_id'] = yeniId;
    item['properties'] = properties;
    return yeniId;
  }

  String _ilkNoktaVarlikIdGetir() {
    if (_haritaVerisi == null) {
      return '';
    }
    for (dynamic item in _haritaVerisi!) {
      Map<String, dynamic> mapItem = _mapOku(item);
      Map<String, dynamic> geometry = _mapOku(mapItem['geometry']);
      if ((geometry['type'] ?? '').toString() == 'Point') {
        return _assetIdGetir(mapItem);
      }
    }
    return '';
  }

  Future<void> _kpiYenile() async {
    Map<String, dynamic>? kpi = await _farmRepository.kpiGetir();
    if (!mounted || kpi == null) {
      return;
    }
    setState(() {
      _kpi = kpi;
    });
  }

  Future<void> _alarmSayisiniYenile() async {
    List<Map<String, dynamic>> items = await _farmRepository.alarmListesiniGetir();
    if (!mounted) {
      return;
    }
    setState(() {
      _alarmSayisi = items.length;
    });
  }

  Future<void> _sahaOrnekIcerikAktar() async {
    LatLng merkez = _kayitliMerkez ?? const LatLng(41.6771, 26.5557);
    List<dynamic>? map = await _farmRepository.sahaVerisiniIceriAktar(
      features: <Map<String, dynamic>>[],
      gpsPoints: <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Saha GPS Noktası',
          'lat': merkez.latitude,
          'lng': merkez.longitude,
          'accuracy_m': 1.3,
          'captured_at': _simdiIso(),
          'operator': 'mobile_user',
        }
      ],
      tkgmContext: <String, dynamic>{
        'source': 'manual_demo',
        'city': 'Edirne',
      },
    );
    if (!mounted || map == null) {
      return;
    }
    setState(() {
      _haritaVerisi = _haritaVerisiniZamanla(map);
      _haritaKey = UniqueKey();
      _varlikYonetimModuAktif = true;
    });
    _yerelDurumuKaydet();
    _kpiYenile();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Saha dijitalleştirme ingest akışı tamamlandı."),
      backgroundColor: Colors.teal,
    ));
  }

  Future<void> _otomatikBakimIsEmriOlustur() async {
    String assetId = _ilkNoktaVarlikIdGetir();
    if (assetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("İş emri için noktasal varlık bulunamadı."),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    Map<String, dynamic>? item = await _farmRepository.isEmriOlustur(
      assetId: assetId,
      title: 'Otomatik bakım kontrolü',
      description: 'Dijital kart üzerinden üretilen bakım iş emri.',
      priority: 'normal',
    );
    if (!mounted || item == null) {
      return;
    }
    _kpiYenile();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('İş emri oluşturuldu: ${item['work_order_id']}'),
      backgroundColor: Colors.blue,
    ));
  }

  Future<void> _varliktanIsEmriTalep(Map<String, dynamic> varlik) async {
    String assetId = _assetIdGetir(varlik);
    if (assetId.isEmpty) {
      return;
    }
    Map<String, dynamic>? item = await _farmRepository.isEmriOlustur(
      assetId: assetId,
      title: "Varlık kartı üzerinden talep",
      description: "Operatör tarafından varlık kartından oluşturuldu.",
      priority: "normal",
    );
    if (!mounted || item == null) {
      return;
    }
    _kpiYenile();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('İş emri oluşturuldu (${item['work_order_id']}).'),
      backgroundColor: Colors.blueGrey,
    ));
  }

  Future<void> _demoTelemetriGonder() async {
    String assetId = _ilkNoktaVarlikIdGetir();
    if (assetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Telemetri için noktasal varlık bulunamadı."),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    await _farmRepository.telemetryGonder(
      assetId: assetId,
      deviceId: 'demo-device-001',
      metrics: <String, dynamic>{
        'soil_moisture_pct': 21.7,
        'air_temperature_c': 34.1,
      },
      measuredAt: _simdiIso(),
    );
    await _alarmSayisiniYenile();
    await _kpiYenile();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Demo telemetri gönderildi."),
      backgroundColor: Colors.orange,
    ));
  }

  Future<void> _erpSenkronBaslat() async {
    Map<String, dynamic>? sonuc =
        await _farmRepository.erpSenkronBaslat(connector: 'generic');
    if (!mounted || sonuc == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('ERP senkron kuyruğa alındı (${sonuc['connector']}).'),
      backgroundColor: Colors.indigo,
    ));
  }

  Map<String, dynamic> _mapOku(dynamic rawMap) {
    if (rawMap is Map<String, dynamic>) {
      return Map<String, dynamic>.from(rawMap);
    }
    if (rawMap is Map) {
      return rawMap.map((dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _auditOku(dynamic rawAudit) {
    if (rawAudit is! List) {
      return <Map<String, dynamic>>[];
    }
    List<Map<String, dynamic>> sonuc = <Map<String, dynamic>>[];
    for (dynamic satir in rawAudit) {
      if (satir is Map<String, dynamic>) {
        sonuc.add(Map<String, dynamic>.from(satir));
      } else if (satir is Map) {
        sonuc.add(satir.map((dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value)));
      }
    }
    return sonuc;
  }

  Map<String, dynamic> _varlikKayitZamaniDamgasiEkle(Map<String, dynamic> asset,
      {required String islemTuru}) {
    Map<String, dynamic> guncelVarlik = Map<String, dynamic>.from(asset);
    Map<String, dynamic> properties = _mapOku(guncelVarlik['properties']);
    String assetId = _assetIdGetir(guncelVarlik);
    Map<String, dynamic> meta = _mapOku(properties['meta']);
    meta['asset_id'] = assetId;
    meta['geometry_type'] = (_mapOku(guncelVarlik['geometry'])['type'] ?? '')
        .toString();
    meta['asset_type'] = (meta['asset_type'] ?? 'non_living').toString();
    meta['category'] = (meta['category'] ?? 'genel').toString();
    meta['version'] = int.tryParse((meta['version'] ?? '1').toString()) ?? 1;
    properties['meta'] = meta;
    properties['asset_id'] = assetId;
    Map<String, dynamic> zaman = _mapOku(properties['timestamps']);
    List<Map<String, dynamic>> audit = _auditOku(properties['audit_log']);
    String simdi = _simdiIso();
    zaman['updated_at'] = simdi;
    zaman['last_operation'] = islemTuru;
    zaman['timezone_offset_min'] =
        DateTime.now().timeZoneOffset.inMinutes.toString();
    zaman['timezone_name'] = DateTime.now().timeZoneName;
    zaman['created_at'] = (zaman['created_at'] ?? simdi).toString();
    audit.add(<String, dynamic>{
      'at': simdi,
      'event': islemTuru,
    });
    properties['timestamps'] = zaman;
    properties['audit_log'] = audit;
    guncelVarlik['properties'] = properties;
    return guncelVarlik;
  }

  List<dynamic> _haritaVerisiniZamanla(List<dynamic> veri) {
    List<dynamic> sonuc = <dynamic>[];
    for (dynamic item in veri) {
      if (item is! Map) {
        sonuc.add(item);
        continue;
      }
      Map<String, dynamic> mapItem = item is Map<String, dynamic>
          ? Map<String, dynamic>.from(item)
          : item.map((dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(key.toString(), value));
      Map<String, dynamic> geometry = _mapOku(mapItem['geometry']);
      String geometryType = (geometry['type'] ?? '').toString();
      if (geometryType == 'Point') {
        sonuc.add(_varlikKayitZamaniDamgasiEkle(mapItem,
            islemTuru: 'asset_loaded_or_synced'));
      } else {
        sonuc.add(mapItem);
      }
    }
    return sonuc;
  }

  @override
  Widget build(BuildContext context) {
    bool editorModu = _varlikYonetimModuAktif &&
        _haritaVerisi != null &&
        _haritaVerisi!.isNotEmpty;
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
              baslangicMerkez: _kayitliMerkez,
              baslangicZoom: _kayitliZoom,
              onKameraDegisti: _kameraDegisti,
              onParselSecildi: _parselSecildi,
              onVarlikEklendi: _varlikEklendi,
              onVarlikGuncellendi: _varlikGuncellendi,
              onIsEmriTalebi: _varliktanIsEmriTalep,
              onVarlikTasindi: _varlikTasindi,
              onVarlikSilindi: _varlikSilindi,
              onTumVarliklarSilindi: _tumVarliklariSil,
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (editorModu)
                      _aksiyonButonu(Icons.arrow_back, "Genel Bakış",
                          Colors.redAccent, _genelBakisaDon)
                    else
                      _aksiyonButonu(Icons.upload_file, "Parsel Yükle",
                          Colors.black54, _dosyaYukleVeCiz),
                    if (editorModu) const SizedBox(width: 8),
                    if (editorModu)
                      _aksiyonButonu(
                          Icons.satellite_alt,
                          _uyduYukleniyor ? "Yükleniyor..." : "Uyduyu Getir",
                          Colors.green.shade700,
                          _uyduYukleniyor ? () {} : () => _uyduyuGetir(),
                          onLongPress: _uyduYukleniyor
                              ? null
                              : () => _uyduyuGetir(zorlaYenile: true)),
                    if (editorModu) const SizedBox(width: 8),
                    if (editorModu)
                      _aksiyonButonu(Icons.fact_check, "Saha Aktar",
                          Colors.teal.shade700, _sahaOrnekIcerikAktar),
                    if (editorModu) const SizedBox(width: 8),
                    if (editorModu)
                      _aksiyonButonu(Icons.assignment_turned_in, "İş Emri",
                          Colors.blueGrey, _otomatikBakimIsEmriOlustur),
                    if (editorModu) const SizedBox(width: 8),
                    if (editorModu)
                      _aksiyonButonu(Icons.sensors, "IoT Demo",
                          Colors.orange.shade700, _demoTelemetriGonder),
                    if (editorModu) const SizedBox(width: 8),
                    if (editorModu)
                      _aksiyonButonu(Icons.sync_alt, "ERP",
                          Colors.indigo.shade600, _erpSenkronBaslat),
                  ],
                ),
                if (editorModu)
                  GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 8),
                      child: Text(
                        _seciliParsel != null
                            ? _seciliParsel!['name']
                            : (_uyduOnbellekten
                                ? "Birleşik Çiftlik • Uydu: Önbellek"
                                : "Birleşik Çiftlik • Uydu: Canlı"),
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                _aksiyonButonu(
                    Icons.logout, "Cikis", Colors.black45, _cikisYap),
              ],
            ),
          ),
          if (editorModu && _uyduSaglayici != "-")
            Positioned(
              top: 92,
              left: 20,
              child: GlassContainer(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    _uyduSaglayiciTarihi == null
                        ? "Kaynak: ${_uyduSaglayici.toUpperCase()} • Tarih: Bilinmiyor ($_uyduSaglayiciTazelikDurumu)"
                        : "Kaynak: ${_uyduSaglayici.toUpperCase()} • ${_uyduSaglayiciTarihi!.day.toString().padLeft(2, '0')}.${_uyduSaglayiciTarihi!.month.toString().padLeft(2, '0')}.${_uyduSaglayiciTarihi!.year}",
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          if (editorModu && _kpi != null)
            Positioned(
              top: 132,
              left: 20,
              child: GlassContainer(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    "KPI • Varlık:${_kpi!['assets_total'] ?? 0} • Açık İş:${_kpi!['work_orders_open'] ?? 0} • Alarm:$_alarmSayisi",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (editorModu)
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VarlikKutuphanesi(
                    seciliArac: _seciliArac, onAracSecildi: _aracSecildi)),
          if (_haritaVerisi == null)
            Center(
                child: GlassContainer(
                    child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.map, size: 50, color: Colors.white54),
                              SizedBox(height: 10),
                              Text(
                                  "Başlamak için sol üstten bir parsel dosyası yükleyin.",
                                  style: TextStyle(color: Colors.white))
                            ])))),
        ],
      ),
    );
  }

  Widget _aksiyonButonu(
      IconData icon, String label, Color color, VoidCallback onTap,
      {VoidCallback? onLongPress}) {
    return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: GlassContainer(
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(30)),
                child: Row(children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))
                ]))));
  }
}
