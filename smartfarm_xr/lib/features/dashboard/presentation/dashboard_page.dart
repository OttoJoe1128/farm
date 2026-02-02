import 'package:flutter/material.dart';
import 'widgets/harita_paneli.dart';
import 'widgets/sol_panel.dart';
import 'widgets/sag_panel.dart';
import 'widgets/components/panel_components.dart';
import '../data/gis_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool solPanelAcik = false;
  bool sagPanelAcik = false;
  
  final GisService _gisService = GisService();
  
  // HARİTAYA GİDECEK VERİ
  List<dynamic>? _haritaVerisi; 

  // Haritayı zorla yenilemek için anahtar
  Key _haritaKey = UniqueKey();

  void _dosyaYukleVeCiz() async {
    List<dynamic>? gelenVeri = await _gisService.haritaYukle();
    
    if (gelenVeri != null) {
      setState(() {
        _haritaVerisi = gelenVeri;
        // KRİTİK HAMLE: Key'i değiştiriyoruz, harita sıfırdan doğuyor!
        _haritaKey = UniqueKey(); 
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${gelenVeri.length} varlık haritaya işlendi!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  void _parselMenuGoster() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ARAZİ YÖNETİMİ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _parselSecenek(Icons.file_upload, "Dosya Yükle (GeoJSON)", "Akıllı analiz ile dijital ikiz oluştur", () {
              Navigator.pop(context);
              _dosyaYukleVeCiz(); 
            }),
            const SizedBox(height: 10),
            _parselSecenek(Icons.draw, "Elle Çizim Yap", "Harita üzerinde parsel sınırlarını çiz", () {
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _parselSecenek(IconData icon, String baslik, String altBaslik, VoidCallback onTap) {
    return GlassContainer(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.greenAccent),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(altBaslik, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ZEMİN (Harita) - Key eklendi!
          Positioned.fill(
            child: HaritaPaneli(
              key: _haritaKey, // <--- İŞTE ÇÖZÜM BURADA
              dijitalIkizVerisi: _haritaVerisi
            ), 
          ),

          // Paneller
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: 0, bottom: 0, left: solPanelAcik ? 0 : -350, width: 320,
            child: Container(color: Colors.black.withOpacity(0.9), child: const SolPanel()),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: 0, bottom: 0, right: sagPanelAcik ? 0 : -350, width: 300,
            child: Container(color: Colors.black.withOpacity(0.9), child: const SagPanel()),
          ),

          // Alt Menü
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuButonu(Icons.add_location_alt, "Parsel", false, _parselMenuGoster),
                    const SizedBox(width: 25),
                    _menuButonu(
                      solPanelAcik ? Icons.view_in_ar : Icons.view_in_ar_outlined, 
                      "Dijital İkiz", solPanelAcik, 
                      () => setState(() { solPanelAcik = !solPanelAcik; if(solPanelAcik) sagPanelAcik = false; })
                    ),
                    const SizedBox(width: 25),
                    _menuButonu(
                      sagPanelAcik ? Icons.notifications_active : Icons.notifications_none, 
                      "Uyarılar", sagPanelAcik, 
                      () => setState(() { sagPanelAcik = !sagPanelAcik; if(sagPanelAcik) solPanelAcik = false; })
                    ),
                    const SizedBox(width: 25),
                    _menuButonu(Icons.settings, "Ayar", false, () {}),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButonu(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? Colors.greenAccent : Colors.white70, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? Colors.greenAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
