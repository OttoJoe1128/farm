import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'varlik_detay_modal.dart'; 

class HaritaPaneli extends StatefulWidget {
  final List<dynamic>? dijitalIkizVerisi;
  
  const HaritaPaneli({super.key, this.dijitalIkizVerisi});

  @override
  State<HaritaPaneli> createState() => _HaritaPaneliState();
}

class _HaritaPaneliState extends State<HaritaPaneli> {
  final MapController _mapController = MapController();
  
  List<Polygon> _polygons = [];
  List<Marker> _markers = [];
  List<Polyline> _gridLines = []; 
  List<LatLng> _odakNoktalari = [];

  // Grid Zoom Ayarı: Daha erken açılsın diye 17'ye çektim
  static const double _gridAcilmaZoomSeviyesi = 17.5;
  static const double _gridAraligiMetre = 2.0;

  @override
  void initState() {
    super.initState();
    if (widget.dijitalIkizVerisi != null && widget.dijitalIkizVerisi!.isNotEmpty) {
      _veriyiIsle();
    }
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    // Zoom seviyesini konsola bas ki kaçta olduğunu görelim
    // debugPrint("Zoom: ${camera.zoom}");
    
    if (camera.zoom >= _gridAcilmaZoomSeviyesi) {
      _gridCizgileriniHesapla(camera);
    } else {
      if (_gridLines.isNotEmpty) {
        setState(() => _gridLines = []);
      }
    }
  }

  void _gridCizgileriniHesapla(MapCamera camera) {
    LatLngBounds bounds = camera.visibleBounds;
    List<Polyline> lines = [];
    
    // Yaklaşık derece/metre dönüşümü
    const double latStepBase = 1 / 111111; 
    double latStep = latStepBase * _gridAraligiMetre;
    
    double centerLatRad = bounds.center.latitude * (math.pi / 180.0);
    double lngStep = latStep / math.cos(centerLatRad);

    // Grid Rengi: SİYAH ve biraz daha belirgin (Blueprint Style)
    // Harita açık renk olduğu için siyah daha iyi görünür.
    Color gridColor = Colors.black.withOpacity(0.25); 

    // Dikey Çizgiler
    double startLng = (bounds.west / lngStep).floor() * lngStep;
    for (double lng = startLng; lng <= bounds.east; lng += lngStep) {
      lines.add(Polyline(
        points: [LatLng(bounds.south, lng), LatLng(bounds.north, lng)],
        color: gridColor,
        strokeWidth: 1.0,
      ));
    }

    // Yatay Çizgiler
    double startLat = (bounds.south / latStep).floor() * latStep;
    for (double lat = startLat; lat <= bounds.north; lat += latStep) {
      lines.add(Polyline(
        points: [LatLng(lat, bounds.west), LatLng(lat, bounds.east)],
        color: gridColor,
        strokeWidth: 1.0,
      ));
    }

    if (lines.length != _gridLines.length || lines.isEmpty) {
        setState(() { _gridLines = lines; });
    } else {
       setState(() { _gridLines = lines; });
    }
  }

  void _modalAc(Map<String, dynamic> veri) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VarlikDetayModal(
        veri: veri,
        onKaydet: (yeniVeri) => setState(() => _veriyiIsle()),
      ),
    );
  }

  // ... (Parsel ve Nokta İşleme Kodları aynı) ...
  List<LatLng> _guvenliKoordinatCozucu(List<dynamic> hamKoordinatlar) {
    List<LatLng> sonuc = [];
    try {
      for (var nokta in hamKoordinatlar) {
        if (nokta is List && nokta.length >= 2) {
          double lng = (nokta[0] as num).toDouble();
          double lat = (nokta[1] as num).toDouble();
          sonuc.add(LatLng(lat, lng));
        }
      }
    } catch (e) {
      debugPrint("Koordinat Hatası: $e");
    }
    return sonuc;
  }

  void _veriyiIsle() {
    if (widget.dijitalIkizVerisi == null) return;

    List<Polygon> yeniPoligonlar = [];
    List<Marker> yeniMarkerlar = [];
    List<LatLng> tumNoktalar = [];

    for (var item in widget.dijitalIkizVerisi!) {
      try {
        String name = item['name'].toString();
        Map geometry = item['geometry'] as Map;
        Map style = item['style'] as Map;
        String geomType = geometry['type'].toString();
        Color color = Color(int.parse(style['color'].toString().replaceAll('#', '0xFF')));

        if (geomType == 'Polygon') {
          List<dynamic> rings = geometry['coordinates'];
          if (rings.isNotEmpty) {
            List<LatLng> points = _guvenliKoordinatCozucu(rings[0]);
            if (points.isNotEmpty) {
              tumNoktalar.addAll(points);
              double latSum = 0, lngSum = 0;
              for(var p in points) { latSum += p.latitude; lngSum += p.longitude; }
              LatLng center = LatLng(latSum / points.length, lngSum / points.length);

              yeniPoligonlar.add(Polygon(
                points: points,
                color: color.withOpacity(0.4),
                borderColor: color.withOpacity(1.0),
                borderStrokeWidth: 3.0,
                label: name,
                labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, backgroundColor: Colors.white70),
              ));

              yeniMarkerlar.add(Marker(
                point: center,
                width: 60, height: 60,
                child: GestureDetector(
                  onTap: () => _modalAc(item as Map<String, dynamic>),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Icon(Icons.touch_app, color: color),
                  ),
                ),
              ));
            }
          }
        } 
        else if (geomType == 'Point') {
          List<dynamic> coords = geometry['coordinates'];
          if (coords.length >= 2) {
             double lng = (coords[0] as num).toDouble();
             double lat = (coords[1] as num).toDouble();
             LatLng point = LatLng(lat, lng);
             tumNoktalar.add(point);
             
             yeniMarkerlar.add(Marker(
                point: point, width: 40, height: 40,
                child: GestureDetector(
                  onTap: () => _modalAc(item as Map<String, dynamic>),
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
             ));
          }
        }
      } catch (e) { debugPrint("Hata: $e"); }
    }

    setState(() {
      _polygons = yeniPoligonlar;
      _markers = yeniMarkerlar;
      _odakNoktalari = tumNoktalar;
    });

    if (tumNoktalar.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () => _kamerayiOdakla());
    }
  }

  void _kamerayiOdakla() {
    if (_odakNoktalari.isEmpty) return;
    try {
      LatLngBounds bounds = LatLngBounds.fromPoints(_odakNoktalari);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
    } catch (e) { debugPrint("Zoom Hatası: $e"); }
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
            onPositionChanged: _onMapPositionChanged,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.smartfarm.xr',
            ),
            // KATMAN SIRALAMASI DEĞİŞTİ:
            // 1. Önce Tarlaları Çiz (Altta kalsın)
            PolygonLayer(polygons: _polygons),
            
            // 2. Sonra Izgarayı Çiz (Tarlanın ÜSTÜNDE görünsün)
            PolylineLayer(polylines: _gridLines),
            
            // 3. En Üste Markerları Koy (Tıklanabilsin)
            MarkerLayer(markers: _markers),
          ],
        ),
        Positioned(
          bottom: 150, right: 20,
          child: FloatingActionButton.extended(
            onPressed: _kamerayiOdakla,
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.my_location),
            label: const Text("Parseli Bul"),
          ),
        ),
        
        if (_gridLines.isNotEmpty)
          Positioned(
            bottom: 30, left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87, // Arka planı koyulaştırdık
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white54)
              ),
              child: const Text(
                "Mühendislik Modu: 2m Izgara", 
                style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)
              ),
            ),
          )
      ],
    );
  }
}
