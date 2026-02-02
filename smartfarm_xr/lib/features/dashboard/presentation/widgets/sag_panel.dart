import 'package:flutter/material.dart';
import 'components/panel_components.dart'; // BAĞLANTI BURADA

class SagPanel extends StatelessWidget {
  const SagPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("UYARILAR", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          
          Expanded(
            child: ListView(
              children: const [
                UyariKarti(baslik: "Kritik Nem Düşüklüğü", mesaj: "3. Parsel nem oranı kritik seviyenin altında (%20)."),
                UyariKarti(baslik: "Yüksek Ateş", mesaj: "TR-04 küpe numaralı inekte yüksek ateş tespit edildi."),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
