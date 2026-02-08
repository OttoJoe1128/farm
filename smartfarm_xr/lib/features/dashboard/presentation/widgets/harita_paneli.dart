import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'varlik_detay_modal.dart'; 

class HaritaPaneli extends StatefulWidget {
  final List<dynamic>? dijitalIkizVerisi;
  final Map<String, dynamic>? seciliParsel; 
  final String? seciliArac; 
  final Function(Map<String, dynamic>)? onParselSecildi; 
  final Function(String, LatLng)? onVarlikEklendi; 
  final Function(int, LatLng)? onVarlikTasindi; 
  final Function(int)? onVarlikSilindi;

  const HaritaPaneli({
    super.key, 
    this.dijitalIkizVerisi, 
    this.seciliParsel,
    this.seciliArac,
    this.onParselSecildi,
    this.onVarlikEklendi,
    this.onVarlikTasindi,
    this.onVarlikSilindi,
  });

  @override
  State<HaritaPaneli> createState() => _HaritaPaneliState();
}

class _HaritaPaneliState extends State<HaritaPaneli> {
  final MapController _mapController = MapController();
  List<Polygon> _polygons = [];
  List<Marker> _markers = [];
  List<Polyline> _gridLines = []; 
  List<LatLng> _odakNoktalari = [];

  bool _editMode = false;
  int? _tasinanVarlikIndex;

  static const double _gridAcilmaZoomSeviyesi = 17.5;
  static const double _gridAraligiMetre = 2.0;

  @override
  void initState() {
    super.initState();
    if (widget.dijitalIkizVerisi != null) _veriyiIsle();
  }

  @override
  void didUpdateWidget(covariant HaritaPaneli oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dijitalIkizVerisi != oldWidget.dijitalIkizVerisi) {
      _veriyiIsle();
    }
    if (widget.seciliParsel != oldWidget.seciliParsel) {
       _veriyiIsle(); 
       Future.delayed(const Duration(milliseconds: 100), () {
         if (widget.seciliParsel != null) _parseleOdaklan(widget.seciliParsel!); else _tumVeriyeOdaklan();
       });
    }
    // Araç seçimi değişince de görünümü güncelle (Nokta moduna geçmek için)
    if (widget.seciliArac != oldWidget.seciliArac) {
      _veriyiIsle();
    }
    if (widget.seciliParsel == null) _editMode = false;
  }

  void _haritaHazir() {
    if (widget.dijitalIkizVerisi != null && widget.dijitalIkizVerisi!.isNotEmpty) {
      if (widget.seciliParsel != null) _parseleOdaklan(widget.seciliParsel!); else _tumVeriyeOdaklan();
    }
  }

  void _haritayaTiklandi(TapPosition tapPosition, LatLng point) {
    if (widget.seciliParsel == null) return;
    if (!_noktaArazideMi(point)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Arazi dışına işlem yapılamaz!"), backgroundColor: Colors.redAccent, duration: Duration(milliseconds: 1000)));
       return;
    }
    if (_tasinanVarlikIndex != null) {
      if (widget.onVarlikTasindi != null) {
        widget.onVarlikTasindi!(_tasinanVarlikIndex!, point);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Konum güncellendi."), backgroundColor: Colors.blue));
      }
      setState(() => _tasinanVarlikIndex = null); 
      return;
    }
    if (widget.seciliArac != null) {
      if (widget.onVarlikEklendi != null) {
        widget.onVarlikEklendi!(widget.seciliArac!, point);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Yeni ${widget.seciliArac} eklendi."), backgroundColor: Colors.green, duration: const Duration(milliseconds: 800)));
      }
    }
  }

  void _silmeOnayiIste(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Varlığı Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Bu varlığı silmek istediğinize emin misiniz?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İPTAL", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onVarlikSilindi != null) widget.onVarlikSilindi!(index);
            },
            child: const Text("EVET, SİL", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _veriyiIsle() {
    if (widget.dijitalIkizVerisi == null) return;
    List<Polygon> yeniPoligonlar = [];
    List<Marker> yeniMarkerlar = [];
    List<LatLng> tumNoktalar = [];
    
    // --- MİNİMALİST MOD KONTROLÜ ---
    // Eğer bir araç seçiliyse (Ekleme Modu), mevcut varlıkları nokta yap.
    bool eklemeModuAktif = widget.seciliArac != null;

    for (int i = 0; i < widget.dijitalIkizVerisi!.length; i++) {
      var item = widget.dijitalIkizVerisi![i];
      try {
        String geomType = item['geometry']['type'].toString();
        Color color = Color(int.parse((item['style']?['color'] ?? '#FFFFFF').toString().replaceAll('#', '0xFF')));

        if (geomType == 'Polygon') {
           List pointsRaw = item['geometry']['coordinates'][0];
           List<LatLng> points = pointsRaw.map((e) => LatLng(e[1], e[0])).toList();
           tumNoktalar.addAll(points);
           
           bool isSelected = (widget.seciliParsel != null && item['name'] == widget.seciliParsel!['name']);
           yeniPoligonlar.add(Polygon(points: points, color: isSelected ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.1), borderColor: isSelected ? Colors.green : Colors.grey, borderStrokeWidth: 2, label: item['name'], labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
           LatLng center = LatLng(points[0].latitude, points[0].longitude); 
           yeniMarkerlar.add(Marker(point: center, width: 100, height: 100, child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () { if (widget.onParselSecildi != null) widget.onParselSecildi!(item); }, child: Container(color: Colors.transparent))));
        }
        else if (geomType == 'Point') {
           List coords = item['geometry']['coordinates'];
           LatLng point = LatLng(coords[1], coords[0]);
           tumNoktalar.add(point);
           String tip = item['style']['icon'];
           
           Widget markerWidget;

           // --- GÖRÜNÜM MANTIĞI ---
           if (eklemeModuAktif) {
             // 1. EKLEME MODU: Sadece küçük noktalar (Görüşü kapatmasın)
             markerWidget = Container(
               decoration: BoxDecoration(
                 color: color,
                 shape: BoxShape.circle,
                 border: Border.all(color: Colors.white.withOpacity(0.5), width: 1)
               ),
             );
             // Nokta modunda boyut küçük olsun
             yeniMarkerlar.add(Marker(point: point, width: 12, height: 12, child: markerWidget));
           } 
           else {
             // 2. NORMAL / EDİTÖR MODU: Tam İkonlar
             markerWidget = _ikonGetir(tip, color, 40);
             
             if (_editMode && widget.seciliParsel != null) {
               bool isMoving = (i == _tasinanVarlikIndex);
               if (isMoving) {
                 markerWidget = const Icon(Icons.gps_fixed, color: Colors.yellowAccent, size: 50);
               } else {
                 markerWidget = Stack(
                   alignment: Alignment.center,
                   clipBehavior: Clip.none,
                   children: [
                     markerWidget,
                     Positioned(right: -10, top: -10, child: GestureDetector(onTap: () => _silmeOnayiIste(i), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)))),
                     Positioned(left: -10, top: -10, child: GestureDetector(onTap: () { setState(() => _tasinanVarlikIndex = i); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yeni yere tıklayın."), backgroundColor: Colors.blue)); }, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle), child: const Icon(Icons.open_with, size: 14, color: Colors.white)))),
                   ],
                 );
               }
             } else {
               markerWidget = GestureDetector(onTap: () => _modalAc(item), child: markerWidget);
             }
             
             yeniMarkerlar.add(Marker(point: point, width: 80, height: 80, child: markerWidget));
           }
        }
      } catch (e) {}
    }
    setState(() { _polygons = yeniPoligonlar; _markers = yeniMarkerlar; _odakNoktalari = tumNoktalar; });
  }

  // ... (Matematiksel Fonksiyonlar - Değişmedi) ...
  void _tumVeriyeOdaklan() { if (_odakNoktalari.isNotEmpty && mounted) _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(_odakNoktalari), padding: const EdgeInsets.all(50))); }
  void _parseleOdaklan(Map<String, dynamic> p) { try { Map g = p['geometry']; List r = g['coordinates']; List<LatLng> pts = _guvenliKoordinatCozucu(r[0]); if(mounted) _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(50))); } catch(e){} }
  LatLng _pikseldenKoordinata(Offset localOffset, Size mapSize) { final centerLatLng = _mapController.camera.center; final zoom = _mapController.camera.zoom; final scale = math.pow(2.0, zoom).toDouble(); final worldSize = 256.0 * scale; final siny = math.sin(centerLatLng.latitude * math.pi / 180.0); final centerWorldX = (centerLatLng.longitude + 180.0) / 360.0 * worldSize; final centerWorldY = (0.5 - math.log((1.0 + siny) / (1.0 - siny)) / (4.0 * math.pi)) * worldSize; final dx = localOffset.dx - (mapSize.width / 2.0); final dy = localOffset.dy - (mapSize.height / 2.0); final targetWorldX = centerWorldX + dx; final targetWorldY = centerWorldY + dy; final targetLng = (targetWorldX / worldSize) * 360.0 - 180.0; final n = math.pi - (2.0 * math.pi * targetWorldY) / worldSize; final targetLat = 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n))); return LatLng(targetLat, targetLng); }
  bool _noktaArazideMi(LatLng p) { if (_polygons.isEmpty) return false; return _isPointInPolygon(p, _polygons[0].points); }
  bool _isPointInPolygon(LatLng p, List<LatLng> pts) { int c = 0; for (int i = 0; i < pts.length - 1; i++) { if (_rayCastIntersect(p, pts[i], pts[i+1])) c++; } if (_rayCastIntersect(p, pts.last, pts.first)) c++; return c % 2 == 1; }
  bool _rayCastIntersect(LatLng p, LatLng a, LatLng b) { double ay = a.latitude; double by = b.latitude; double ax = a.longitude; double bx = b.longitude; double py = p.latitude; double px = p.longitude; if ((ay > py && by > py) || (ay < py && by < py) || (ax < px && bx < px)) return false; if (ay == by) return false; double m = (by - ay) / (bx - ax); double bee = (-ax) * m + ay; double x = (py - bee) / m; return x > px; }
  void _modalAc(Map<String, dynamic> v) { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => VarlikDetayModal(veri: v, onKaydet: (v){})); }
  List<LatLng> _guvenliKoordinatCozucu(List<dynamic> h) { List<LatLng> s = []; try{ for(var n in h) if(n is List && n.length>=2) s.add(LatLng((n[1] as num).toDouble(), (n[0] as num).toDouble())); }catch(e){} return s; }
  void _onMapPositionChanged(MapCamera c, bool g) { if (widget.seciliParsel != null && c.zoom >= _gridAcilmaZoomSeviyesi) _gridCizgileriniHesapla(c); else if (_gridLines.isNotEmpty) setState(() => _gridLines = []); }
  void _gridCizgileriniHesapla(MapCamera c) { LatLngBounds b = c.visibleBounds; List<Polyline> l = []; const double base = 1/111111; double step = base*_gridAraligiMetre; double rad = b.center.latitude*(math.pi/180); double lstep = step/math.cos(rad); Color col = Colors.black.withOpacity(0.25); double sl = (b.west/lstep).floor()*lstep; for(double i=sl; i<=b.east; i+=lstep) l.add(Polyline(points:[LatLng(b.south, i), LatLng(b.north, i)], color:col, strokeWidth:1)); double slat = (b.south/step).floor()*step; for(double i=slat; i<=b.north; i+=step) l.add(Polyline(points:[LatLng(i, b.west), LatLng(i, b.east)], color:col, strokeWidth:1)); setState(()=>_gridLines=l); }

  Widget _ikonGetir(String tip, Color color, double size) {
    IconData icon = Icons.location_on;
    if (tip == 'park' || tip == 'agac') icon = Icons.park;
    if (tip == 'home' || tip == 'yapi') icon = Icons.home;
    if (tip == 'water_drop' || tip == 'kuyu') icon = Icons.water_drop;
    if (tip == 'sensor') icon = Icons.sensors;
    if (tip == 'gunes') icon = Icons.solar_power;
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4)]),
      child: Icon(icon, color: Colors.white, size: size * 0.7),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(41.6771, 26.5557), 
            initialZoom: 13.0, 
            onMapReady: _haritaHazir,
            onPositionChanged: _onMapPositionChanged,
            onTap: _haritayaTiklandi, 
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.smartfarm.xr'),
            PolygonLayer(polygons: _polygons),
            PolylineLayer(polylines: _gridLines),
            MarkerLayer(markers: _markers),
          ],
        ),
        if (_gridLines.isNotEmpty && widget.seciliParsel != null) Positioned(bottom: 100, left: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal:12,vertical:6), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)), child: const Text("Editör Modu: 2m Izgara", style: TextStyle(color: Colors.greenAccent, fontSize: 10)))),
        if (widget.seciliParsel != null) Positioned(right: 20, bottom: 150, child: FloatingActionButton(onPressed: () { setState(() { _editMode = !_editMode; _tasinanVarlikIndex = null; _veriyiIsle(); }); }, backgroundColor: _editMode ? Colors.orange : Colors.white, child: Icon(_editMode ? Icons.check : Icons.edit, color: _editMode ? Colors.white : Colors.black87))),
        if (_tasinanVarlikIndex != null) Positioned(top: 100, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(30)), child: const Text("📍 Yeni konuma tıklayın...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
      ],
    );
  }
}
