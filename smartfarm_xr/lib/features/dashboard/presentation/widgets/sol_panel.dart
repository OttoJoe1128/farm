import 'package:flutter/material.dart';
import 'components/panel_components.dart';

class SolPanel extends StatefulWidget {
  const SolPanel({super.key});

  @override
  State<SolPanel> createState() => _SolPanelState();
}

class _SolPanelState extends State<SolPanel> {
  int _seciliKategori = 0; // 0: Hayvanlar, 1: Bitkiler, 2: Ağaçlar

  // SİMÜLASYON VERİLERİ
  final List<List<Widget>> _veriListeleri = [
    // 0: HAYVANLAR
    [
      const VarlikKarti(baslik: "Sarıkız (TR-01)", durum: "NORMAL", detay: "Süt: 24L | Yem: %100", ikon: Icons.pets, renk: Colors.orange),
      const VarlikKarti(baslik: "Benekli (TR-04)", durum: "HASTA", detay: "Ateş: 39.5°C | Tedavi", ikon: Icons.local_hospital, renk: Colors.red),
      const VarlikKarti(baslik: "Koyun Sürüsü A", durum: "MERADA", detay: "Konum: Kuzey Parsel", ikon: Icons.gps_fixed, renk: Colors.blue),
    ],
    // 1: BİTKİLER
    [
      const VarlikKarti(baslik: "Mısır Tarlası", durum: "SULANIYOR", detay: "Nem: %35 (Hedef %45)", ikon: Icons.grass, renk: Colors.green),
      const VarlikKarti(baslik: "Buğday (P-2)", durum: "KURAK", detay: "Hasata 15 gün", ikon: Icons.warning, renk: Colors.amber),
    ],
    // 2: AĞAÇLAR
    [
      const VarlikKarti(baslik: "Ceviz Bahçesi", durum: "İYİ", detay: "Budama yapıldı", ikon: Icons.park, renk: Colors.greenAccent),
      const VarlikKarti(baslik: "Zeytinlik", durum: "KONTROL", detay: "İlaçlama bekleniyor", ikon: Icons.nature, renk: Colors.teal),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DİJİTAL İKİZ", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          
          // DÜZELTME BURADA: Wrap Kullanıldı
          // Butonlar sığmazsa aşağı kayacak, ekran dışına çıkmayacak.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,      // Yatay boşluk
              runSpacing: 10,   // Dikey boşluk (alt satıra geçerse)
              alignment: WrapAlignment.start, 
              children: [
                _kategoriChip("Hayvanlar", Icons.pets, 0),
                _kategoriChip("Bitkiler", Icons.grass, 1),
                _kategoriChip("Ağaçlar", Icons.park, 2),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // LİSTE
          Expanded(
            child: ListView(
              children: _veriListeleri[_seciliKategori],
            ),
          ),
          
          // Ekleme Butonu
          Center(
            child: TextButton.icon(
              onPressed: () => debugPrint("Yeni Ekle"),
              icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
              label: const Text("Yeni Varlık Ekle", style: TextStyle(color: Colors.white54)),
            ),
          )
        ],
      ),
    );
  }

  Widget _kategoriChip(String label, IconData icon, int index) {
    bool isActive = _seciliKategori == index;
    return GestureDetector(
      onTap: () => setState(() => _seciliKategori = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.greenAccent.withOpacity(0.2) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? Colors.greenAccent : Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.greenAccent : Colors.white70),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isActive ? Colors.greenAccent : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
