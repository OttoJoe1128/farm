import 'package:flutter/material.dart';

class VarlikKutuphanesi extends StatelessWidget {
  final String? seciliArac; // Hangi araç seçili? (agac, kuyu vs.)
  final Function(String) onAracSecildi; // Seçilince Dashboard'a haber ver

  const VarlikKutuphanesi(
      {super.key, required this.seciliArac, required this.onAracSecildi});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 30),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // Koyu şık zemin
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _aracButonu("agac", Icons.park, Colors.green, "Ağaç"),
            const SizedBox(width: 15),
            _aracButonu("yapi", Icons.home, Colors.brown, "Yapı"),
            const SizedBox(width: 15),
            _aracButonu("kuyu", Icons.water_drop, Colors.blue, "Su"),
            const SizedBox(width: 15),
            _aracButonu("sensor", Icons.sensors, Colors.orange, "IoT"),
            const SizedBox(width: 15),
            _aracButonu("gunes", Icons.solar_power, Colors.yellow, "Enerji"),
            const SizedBox(width: 15),
            _aracButonu("olcum", Icons.straighten, Colors.cyan, "Ölçüm"),
          ],
        ),
      ),
    );
  }

  Widget _aracButonu(String tip, IconData icon, Color renk, String etiket) {
    bool aktif = seciliArac == tip;

    return GestureDetector(
      onTap: () => onAracSecildi(tip),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(aktif ? 16 : 12),
        decoration: BoxDecoration(
          color: aktif ? renk.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border:
              Border.all(color: aktif ? renk : Colors.transparent, width: 2),
          boxShadow: aktif
              ? [BoxShadow(color: renk.withOpacity(0.4), blurRadius: 10)]
              : [],
        ),
        child: Icon(icon,
            color: aktif ? renk : renk.withOpacity(0.5), size: aktif ? 32 : 24),
      ),
    );
  }
}
