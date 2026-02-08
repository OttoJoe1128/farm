import 'package:flutter/material.dart';

class VarlikDetayModal extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Function(Map<String, dynamic>) onKaydet;

  const VarlikDetayModal({super.key, required this.veri, required this.onKaydet});

  @override
  State<VarlikDetayModal> createState() => _VarlikDetayModalState();
}

class _VarlikDetayModalState extends State<VarlikDetayModal> {
  late TextEditingController _isimController;
  bool iotBagli = false;
  String seciliTur = "";

  @override
  void initState() {
    super.initState();
    _isimController = TextEditingController(text: widget.veri['name']);
    seciliTur = widget.veri['style']?['icon'] ?? 'agac';
    iotBagli = widget.veri['properties']?['iot_connected'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Klavye açılınca ekranı yukarı itmesi için padding
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: bottomPadding + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Koyu tema arka plan
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85, // Ekranın %85'inden büyük olmasın
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BAŞLIK VE KAPAT BUTONU
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("VARLIK YÖNETİMİ", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white24),

          // --- İÇERİK (SCROLLABLE YAPILDI) ---
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // İSİM ALANI
                  const Text("Varlık İsmi", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _isimController,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "İsim Giriniz",
                      hintStyle: TextStyle(color: Colors.white24),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 15),

                  // TÜR SEÇİMİ
                  const Text("VARLIK TÜRÜ", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _turSecimButonu("Tarla", "tarla", Icons.landscape),
                        _turSecimButonu("Ağaç", "agac", Icons.park),
                        _turSecimButonu("Yapı", "yapi", Icons.home),
                        _turSecimButonu("Kuyu", "kuyu", Icons.water_drop),
                        _turSecimButonu("Sensör", "sensor", Icons.sensors),
                        _turSecimButonu("Altyapı", "altyapi", Icons.timeline),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // IOT BAĞLANTISI
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Icon(iotBagli ? Icons.sensors : Icons.sensors_off, color: iotBagli ? Colors.greenAccent : Colors.white24, size: 30),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("IoT Sensör Bağlantısı", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(iotBagli ? "Cihaz Eşleştirildi" : "Cihaz eşleştirilmedi", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Switch(
                          value: iotBagli,
                          activeColor: Colors.greenAccent,
                          onChanged: (val) => setState(() => iotBagli = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // KAYDET BUTONU (ALTTA SABİT)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.veri['name'] = _isimController.text;
                widget.veri['style'] = {'icon': seciliTur, 'color': '#FFFFFF'}; // Basit stil güncellemesi
                widget.veri['properties'] = {'iot_connected': iotBagli};
                widget.onKaydet(widget.veri);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.save),
              label: const Text("DİJİTAL İKİZİ GÜNCELLE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _turSecimButonu(String label, String value, IconData icon) {
    bool isSelected = seciliTur == value;
    return GestureDetector(
      onTap: () => setState(() => seciliTur = value),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.greenAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.greenAccent : Colors.white54),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
