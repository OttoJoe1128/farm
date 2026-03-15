import 'package:flutter/material.dart';

class VarlikDetayModal extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Function(Map<String, dynamic>) onKaydet;
  final VoidCallback? onIsEmriOlustur;

  const VarlikDetayModal(
      {super.key,
      required this.veri,
      required this.onKaydet,
      this.onIsEmriOlustur});

  @override
  State<VarlikDetayModal> createState() => _VarlikDetayModalState();
}

class _VarlikDetayModalState extends State<VarlikDetayModal> {
  late TextEditingController _isimController;
  late TextEditingController _notlarController;
  late TextEditingController _fotoController;
  late TextEditingController _kodController;
  late TextEditingController _turController;
  late TextEditingController _cesitController;
  late TextEditingController _yasController;
  late TextEditingController _dikimTarihiController;
  late TextEditingController _anacController;
  late TextEditingController _siraNoController;
  late TextEditingController _agacNoController;
  late TextEditingController _hastalikController;
  late TextEditingController _belirtiController;
  late TextEditingController _zararliController;
  late TextEditingController _siddetController;
  late TextEditingController _tedaviController;
  late TextEditingController _toprakNemController;
  late TextEditingController _govdeSicaklikController;
  late TextEditingController _havaSicaklikController;
  late TextEditingController _nemController;
  late TextEditingController _phController;
  late TextEditingController _ecController;
  late TextEditingController _bataryaController;
  late TextEditingController _sinyalController;
  late TextEditingController _sonGorulmeController;
  late TextEditingController _sulamaSonController;
  late TextEditingController _budamaSonController;
  late TextEditingController _gubreSonController;
  late TextEditingController _ilaclamaSonController;
  late TextEditingController _verimGecenYilController;
  late TextEditingController _verimBeklenenController;
  late TextEditingController _meyveSayisiController;
  late TextEditingController _nemMinAlarmController;
  late TextEditingController _nemMaxAlarmController;
  late TextEditingController _sicaklikMinAlarmController;
  late TextEditingController _sicaklikMaxAlarmController;
  bool iotBagli = false;
  String seciliTur = "";

  TextEditingController _controllerFromMap(
      Map<String, dynamic> mapData, String key,
      {String fallback = ''}) {
    return TextEditingController(
        text: (mapData[key] ?? fallback).toString());
  }

  Map<String, dynamic> _readMap(dynamic rawValue) {
    if (rawValue is Map<String, dynamic>) {
      return Map<String, dynamic>.from(rawValue);
    }
    if (rawValue is Map) {
      return rawValue.map((dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  String _simdiIso() {
    return DateTime.now().toUtc().toIso8601String();
  }

  @override
  void initState() {
    super.initState();
    Map<String, dynamic> properties =
        _readMap(widget.veri['properties']);
    Map<String, dynamic> digitalCard =
        _readMap(properties['digital_card']);
    Map<String, dynamic> genelCard = _readMap(digitalCard['genel']);
    Map<String, dynamic> agacCard = _readMap(digitalCard['agac']);
    Map<String, dynamic> saglikCard = _readMap(digitalCard['saglik']);
    Map<String, dynamic> iotCard = _readMap(digitalCard['iot']);
    Map<String, dynamic> bakimCard = _readMap(digitalCard['bakim']);
    Map<String, dynamic> uretimCard = _readMap(digitalCard['uretim']);
    Map<String, dynamic> alarmCard = _readMap(digitalCard['alarm']);

    _isimController =
        TextEditingController(text: (widget.veri['name'] ?? '').toString());
    seciliTur = widget.veri['style']?['icon'] ?? 'agac';
    iotBagli = widget.veri['properties']?['iot_connected'] ?? false;
    _notlarController = _controllerFromMap(genelCard, 'notes');
    _fotoController = _controllerFromMap(genelCard, 'photo_urls');
    _kodController = _controllerFromMap(genelCard, 'asset_code');
    _turController = _controllerFromMap(agacCard, 'species');
    _cesitController = _controllerFromMap(agacCard, 'variety');
    _yasController = _controllerFromMap(agacCard, 'age_years');
    _dikimTarihiController = _controllerFromMap(agacCard, 'planting_date');
    _anacController = _controllerFromMap(agacCard, 'rootstock');
    _siraNoController = _controllerFromMap(agacCard, 'row_no');
    _agacNoController = _controllerFromMap(agacCard, 'tree_no');
    _hastalikController = _controllerFromMap(saglikCard, 'disease_name');
    _belirtiController = _controllerFromMap(saglikCard, 'symptoms');
    _zararliController = _controllerFromMap(saglikCard, 'pest_name');
    _siddetController = _controllerFromMap(saglikCard, 'severity');
    _tedaviController = _controllerFromMap(saglikCard, 'treatment_plan');
    _toprakNemController = _controllerFromMap(iotCard, 'soil_moisture_pct');
    _govdeSicaklikController =
        _controllerFromMap(iotCard, 'trunk_temperature_c');
    _havaSicaklikController = _controllerFromMap(iotCard, 'air_temperature_c');
    _nemController = _controllerFromMap(iotCard, 'air_humidity_pct');
    _phController = _controllerFromMap(iotCard, 'soil_ph');
    _ecController = _controllerFromMap(iotCard, 'soil_ec');
    _bataryaController = _controllerFromMap(iotCard, 'battery_pct');
    _sinyalController = _controllerFromMap(iotCard, 'signal_dbm');
    _sonGorulmeController = _controllerFromMap(iotCard, 'last_seen_at');
    _sulamaSonController = _controllerFromMap(bakimCard, 'last_irrigation_at');
    _budamaSonController = _controllerFromMap(bakimCard, 'last_pruning_at');
    _gubreSonController =
        _controllerFromMap(bakimCard, 'last_fertilization_at');
    _ilaclamaSonController = _controllerFromMap(bakimCard, 'last_spray_at');
    _verimGecenYilController = _controllerFromMap(uretimCard, 'last_yield_kg');
    _verimBeklenenController =
        _controllerFromMap(uretimCard, 'expected_yield_kg');
    _meyveSayisiController = _controllerFromMap(uretimCard, 'fruit_count_est');
    _nemMinAlarmController = _controllerFromMap(alarmCard, 'soil_moisture_min');
    _nemMaxAlarmController = _controllerFromMap(alarmCard, 'soil_moisture_max');
    _sicaklikMinAlarmController =
        _controllerFromMap(alarmCard, 'air_temperature_min');
    _sicaklikMaxAlarmController =
        _controllerFromMap(alarmCard, 'air_temperature_max');
  }

  @override
  void dispose() {
    _isimController.dispose();
    _notlarController.dispose();
    _fotoController.dispose();
    _kodController.dispose();
    _turController.dispose();
    _cesitController.dispose();
    _yasController.dispose();
    _dikimTarihiController.dispose();
    _anacController.dispose();
    _siraNoController.dispose();
    _agacNoController.dispose();
    _hastalikController.dispose();
    _belirtiController.dispose();
    _zararliController.dispose();
    _siddetController.dispose();
    _tedaviController.dispose();
    _toprakNemController.dispose();
    _govdeSicaklikController.dispose();
    _havaSicaklikController.dispose();
    _nemController.dispose();
    _phController.dispose();
    _ecController.dispose();
    _bataryaController.dispose();
    _sinyalController.dispose();
    _sonGorulmeController.dispose();
    _sulamaSonController.dispose();
    _budamaSonController.dispose();
    _gubreSonController.dispose();
    _ilaclamaSonController.dispose();
    _verimGecenYilController.dispose();
    _verimBeklenenController.dispose();
    _meyveSayisiController.dispose();
    _nemMinAlarmController.dispose();
    _nemMaxAlarmController.dispose();
    _sicaklikMinAlarmController.dispose();
    _sicaklikMaxAlarmController.dispose();
    super.dispose();
  }

  Widget _kartBasligi(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 14),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _alan(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.greenAccent)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
          top: 20, left: 20, right: 20, bottom: bottomPadding + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("DİJİTAL VARLIK KARTI",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _alan("Varlık İsmi", _isimController),
                  _alan("Varlık Kodu / Etiket", _kodController),
                  _alan("Notlar", _notlarController),
                  _alan("Foto URL listesi (virgül ile)", _fotoController),
                  const SizedBox(height: 8),
                  const Text("VARLIK TÜRÜ",
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                        _turSecimButonu("Enerji", "gunes", Icons.solar_power),
                      ],
                    ),
                  ),
                  _kartBasligi("Akıllı Nesne / IoT"),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Icon(iotBagli ? Icons.sensors : Icons.sensors_off,
                            color: iotBagli
                                ? Colors.greenAccent
                                : Colors.white24,
                            size: 30),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("IoT Sensör Bağlantısı",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  iotBagli
                                      ? "Cihaz Eşleştirildi"
                                      : "Cihaz eşleştirilmedi",
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
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
                  if (seciliTur == 'agac') ...[
                    _kartBasligi("Ağaç Kimliği"),
                    _alan("Tür (Species)", _turController),
                    _alan("Çeşit (Variety)", _cesitController),
                    _alan("Yaş (Yıl)", _yasController,
                        keyboardType: TextInputType.number),
                    _alan("Dikim Tarihi (YYYY-MM-DD)", _dikimTarihiController),
                    _alan("Anaç", _anacController),
                    _alan("Sıra No", _siraNoController),
                    _alan("Ağaç No", _agacNoController),
                    _kartBasligi("Sağlık ve Hastalık"),
                    _alan("Hastalık Adı", _hastalikController),
                    _alan("Belirti / Semptomlar", _belirtiController),
                    _alan("Zararlı", _zararliController),
                    _alan("Şiddet Skoru (0-100)", _siddetController,
                        keyboardType: TextInputType.number),
                    _alan("Tedavi Planı", _tedaviController),
                    _kartBasligi("Canlı Sensör Verileri"),
                    _alan("Toprak Nem (%)", _toprakNemController,
                        keyboardType: TextInputType.number),
                    _alan("Gövde Sıcaklığı (C)", _govdeSicaklikController,
                        keyboardType: TextInputType.number),
                    _alan("Hava Sıcaklığı (C)", _havaSicaklikController,
                        keyboardType: TextInputType.number),
                    _alan("Hava Nem (%)", _nemController,
                        keyboardType: TextInputType.number),
                    _alan("Toprak pH", _phController,
                        keyboardType: TextInputType.number),
                    _alan("Toprak EC", _ecController,
                        keyboardType: TextInputType.number),
                    _alan("Batarya (%)", _bataryaController,
                        keyboardType: TextInputType.number),
                    _alan("Sinyal (dBm)", _sinyalController,
                        keyboardType: TextInputType.number),
                    _alan("Son Görülme (ISO Tarih)", _sonGorulmeController),
                    _kartBasligi("Bakım Geçmişi"),
                    _alan("Son Sulama", _sulamaSonController),
                    _alan("Son Budama", _budamaSonController),
                    _alan("Son Gübreleme", _gubreSonController),
                    _alan("Son İlaçlama", _ilaclamaSonController),
                    _kartBasligi("Üretim"),
                    _alan("Geçen Yıl Verim (kg)", _verimGecenYilController,
                        keyboardType: TextInputType.number),
                    _alan("Beklenen Verim (kg)", _verimBeklenenController,
                        keyboardType: TextInputType.number),
                    _alan("Meyve Sayısı Tahmini", _meyveSayisiController,
                        keyboardType: TextInputType.number),
                    _kartBasligi("Alarm Eşikleri"),
                    _alan("Toprak Nem Min", _nemMinAlarmController,
                        keyboardType: TextInputType.number),
                    _alan("Toprak Nem Max", _nemMaxAlarmController,
                        keyboardType: TextInputType.number),
                    _alan("Sıcaklık Min", _sicaklikMinAlarmController,
                        keyboardType: TextInputType.number),
                    _alan("Sıcaklık Max", _sicaklikMaxAlarmController,
                        keyboardType: TextInputType.number),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Map<String, dynamic> guncelVeri =
                    Map<String, dynamic>.from(widget.veri);
                Map<String, dynamic> mevcutProperties =
                    _readMap(guncelVeri['properties']);
                guncelVeri['name'] = _isimController.text.trim();
                Map<String, dynamic> mevcutStyle = _readMap(guncelVeri['style']);
                mevcutStyle['icon'] = seciliTur;
                mevcutStyle['color'] = mevcutStyle['color'] ?? '#FFFFFF';
                guncelVeri['style'] = mevcutStyle;
                mevcutProperties['iot_connected'] = iotBagli;
                String simdi = _simdiIso();
                mevcutProperties['digital_card'] = {
                  'genel': {
                    'asset_code': _kodController.text.trim(),
                    'notes': _notlarController.text.trim(),
                    'photo_urls': _fotoController.text.trim(),
                    'last_update_source': 'manual_card',
                    'updated_at': simdi,
                  },
                  'agac': {
                    'species': _turController.text.trim(),
                    'variety': _cesitController.text.trim(),
                    'age_years': _yasController.text.trim(),
                    'planting_date': _dikimTarihiController.text.trim(),
                    'rootstock': _anacController.text.trim(),
                    'row_no': _siraNoController.text.trim(),
                    'tree_no': _agacNoController.text.trim(),
                    'updated_at': simdi,
                  },
                  'saglik': {
                    'disease_name': _hastalikController.text.trim(),
                    'symptoms': _belirtiController.text.trim(),
                    'pest_name': _zararliController.text.trim(),
                    'severity': _siddetController.text.trim(),
                    'treatment_plan': _tedaviController.text.trim(),
                    'updated_at': simdi,
                  },
                  'iot': {
                    'soil_moisture_pct': _toprakNemController.text.trim(),
                    'trunk_temperature_c': _govdeSicaklikController.text.trim(),
                    'air_temperature_c': _havaSicaklikController.text.trim(),
                    'air_humidity_pct': _nemController.text.trim(),
                    'soil_ph': _phController.text.trim(),
                    'soil_ec': _ecController.text.trim(),
                    'battery_pct': _bataryaController.text.trim(),
                    'signal_dbm': _sinyalController.text.trim(),
                    'last_seen_at': _sonGorulmeController.text.trim(),
                    'updated_at': simdi,
                  },
                  'bakim': {
                    'last_irrigation_at': _sulamaSonController.text.trim(),
                    'last_pruning_at': _budamaSonController.text.trim(),
                    'last_fertilization_at': _gubreSonController.text.trim(),
                    'last_spray_at': _ilaclamaSonController.text.trim(),
                    'updated_at': simdi,
                  },
                  'uretim': {
                    'last_yield_kg': _verimGecenYilController.text.trim(),
                    'expected_yield_kg': _verimBeklenenController.text.trim(),
                    'fruit_count_est': _meyveSayisiController.text.trim(),
                    'updated_at': simdi,
                  },
                  'alarm': {
                    'soil_moisture_min': _nemMinAlarmController.text.trim(),
                    'soil_moisture_max': _nemMaxAlarmController.text.trim(),
                    'air_temperature_min':
                        _sicaklikMinAlarmController.text.trim(),
                    'air_temperature_max':
                        _sicaklikMaxAlarmController.text.trim(),
                    'updated_at': simdi,
                  },
                  'meta': {
                    'updated_at': simdi,
                    'timezone_offset_min':
                        DateTime.now().timeZoneOffset.inMinutes.toString(),
                    'timezone_name': DateTime.now().timeZoneName,
                  },
                };
                guncelVeri['properties'] = mevcutProperties;
                widget.onKaydet(guncelVeri);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.save),
              label: const Text("DİJİTAL KARTI KAYDET",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.onIsEmriOlustur != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onIsEmriOlustur,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.assignment_add),
                label: const Text("BU VARLIK İÇİN İŞ EMRİ OLUŞTUR"),
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
            Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
