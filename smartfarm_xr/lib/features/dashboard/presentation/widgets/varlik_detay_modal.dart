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
  late String _seciliTip;
  bool _iotBagliMi = false;

  final Map<String, IconData> _tipler = {
    'tarla': Icons.landscape,
    'agac': Icons.park,
    'yapi': Icons.home,
    'kuyu': Icons.water_drop,
    'sensor': Icons.sensors,
    'altyapi': Icons.timeline,
  };

  @override
  void initState() {
    super.initState();
    _isimController = TextEditingController(text: widget.veri['name']);
    _seciliTip = widget.veri['type'] ?? 'tarla';
    _iotBagliMi = widget.veri['properties']?['iot_connected'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BAŞLIK
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("VARLIK YÖNETİMİ", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
            ],
          ),
          
          const SizedBox(height: 10),

          // 1. İSİM GİRİŞİ
          TextField(
            controller: _isimController,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: "Varlık İsmi",
              labelStyle: TextStyle(color: Colors.greenAccent.withOpacity(0.7)),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
            ),
          ),

          const SizedBox(height: 20),

          // 2. TİP SEÇİMİ
          const Text("VARLIK TÜRÜ", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _tipler.entries.map((entry) {
              bool secili = _seciliTip == entry.key;
              return ChoiceChip(
                label: Text(entry.key.toUpperCase()),
                labelStyle: TextStyle(color: secili ? Colors.black : Colors.white70, fontSize: 10),
                avatar: Icon(entry.value, size: 16, color: secili ? Colors.black : Colors.white70),
                selected: secili,
                selectedColor: Colors.greenAccent,
                backgroundColor: Colors.white10,
                onSelected: (val) => setState(() => _seciliTip = entry.key),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // 3. IOT ENTEGRASYONU
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _iotBagliMi ? Colors.greenAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _iotBagliMi ? Colors.greenAccent : Colors.white10),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_tethering, color: _iotBagliMi ? Colors.greenAccent : Colors.white54),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("IoT Sensör Bağlantısı", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(_iotBagliMi ? "Bağlı: SN-83921 (Aktif)" : "Cihaz eşleştirilmedi", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _iotBagliMi,
                  activeColor: Colors.greenAccent,
                  onChanged: (val) => setState(() => _iotBagliMi = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // KAYDET BUTONU
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.veri['name'] = _isimController.text;
                widget.veri['type'] = _seciliTip;
                if (widget.veri['properties'] == null) widget.veri['properties'] = {};
                widget.veri['properties']['iot_connected'] = _iotBagliMi;
                
                widget.onKaydet(widget.veri);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save),
              label: const Text("DİJİTAL İKİZİ GÜNCELLE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
