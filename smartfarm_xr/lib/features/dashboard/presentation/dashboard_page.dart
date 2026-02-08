import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'widgets/harita_paneli.dart';
import 'widgets/sol_panel.dart';
import 'widgets/sag_panel.dart';
import 'widgets/varlik_kutuphanesi.dart';
import 'widgets/components/panel_components.dart';
import '../data/gis_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GisService _gisService = GisService();
  List<dynamic>? _haritaVerisi; 
  Map<String, dynamic>? _seciliParsel; 
  String? _seciliArac; 
  Key _haritaKey = UniqueKey();

  void _dosyaYukleVeCiz() async {
    List<dynamic>? gelenVeri = await _gisService.haritaYukle();
    if (gelenVeri != null && gelenVeri.isNotEmpty) {
      setState(() {
        _haritaVerisi = gelenVeri;
        _haritaKey = UniqueKey();
        
        // --- DÜZELTME BURADA: OTOMATİK SEÇİM ---
        // Eğer dosyada veri varsa, ilk parseli otomatik seç!
        // Böylece kullanıcı tıklamak zorunda kalmaz.
        _seciliParsel = gelenVeri[0]; 
        _seciliArac = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dijital İkiz Yüklendi ve Hazır!"), backgroundColor: Colors.blue));
    }
  }

  void _parselSecildi(Map<String, dynamic> parsel) {
    setState(() => _seciliParsel = parsel);
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
      guncelListe.add({
        "name": "Yeni ${tip.toUpperCase()}",
        "type": "Point",
        "geometry": { "type": "Point", "coordinates": [konum.longitude, konum.latitude] },
        "style": {"color": "#FF0000", "icon": tip},
        "properties": {"iot_connected": false}
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

  void _genelBakisaDon() { setState(() { _seciliParsel = null; _seciliArac = null; }); }

  @override
  Widget build(BuildContext context) {
    bool editorModu = _seciliParsel != null;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: HaritaPaneli(
              key: _haritaKey,
              dijitalIkizVerisi: _haritaVerisi,
              seciliParsel: _seciliParsel, 
              seciliArac: _seciliArac, 
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
                  ],
                ),
                if (editorModu) GlassContainer(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), child: Text(_seciliParsel!['name'], style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))))
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
