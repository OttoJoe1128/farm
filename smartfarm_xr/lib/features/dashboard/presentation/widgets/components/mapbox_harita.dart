import 'package:flutter/material.dart';
// import 'package:mapbox_gl/mapbox_gl.dart'; // Geçici olarak devre dışı - Dart 3.5 uyumluluk sorunu
import 'package:smartfarm_xr/core/utils/mapbox_types.dart';
import 'package:smartfarm_xr/core/config/mapbox_config.dart';

/// Mapbox Harita Controller
/// Harita işlemlerini yönetir
class MapboxHaritaController {
  List<LatLng> fencePoints = [];
  List<Map<String, dynamic>> geojsonParcels = [];
  bool hasActiveArea = false;

  void setStyle(String style) {
    // TODO: Harita stilini değiştir
  }

  void toggleDevices(bool show) {
    // TODO: Cihazları göster/gizle
  }

  void addTree(LatLng position, String label) {
    // TODO: Ağaç ekle
  }

  void addBuilding(LatLng position, String label) {
    // TODO: Bina ekle
  }

  void addSensor(LatLng position, String label) {
    // TODO: Sensör ekle
  }

  void addCamera(LatLng position, String label) {
    // TODO: Kamera ekle
  }

  void addPump(LatLng position, String label) {
    // TODO: Pompa ekle
  }

  void addByScreenOffset(String tool, Offset offset) {
    // TODO: Ekran koordinatından konum ekle
  }

  void showLocation(LatLng position) {
    // TODO: Konumu haritada göster
  }

  List<LatLng> getFencePoints() {
    return fencePoints;
  }

  bool hasGeoJSONParcels() {
    return geojsonParcels.isNotEmpty;
  }

  List<Map<String, dynamic>> getGeoJSONParcels() {
    return geojsonParcels;
  }

  void setTreeClustering(bool enabled) {
    // TODO: Ağaç kümeleme ayarla
  }

  Future<void> plantGridTrees(int rows, int cols) async {
    // TODO: Izgara düzeninde ağaç dik
  }

  Future<void> plantAlongFence(double spacing) async {
    // TODO: Çit boyunca ağaç dik
  }

  Future<void> plantRandomTrees(int count) async {
    // TODO: Rastgele ağaç dik
  }

  Future<void> importTrees() async {
    // TODO: Ağaçları içe aktar
  }

  Future<void> clearTrees() async {
    // TODO: Ağaçları temizle
  }
}

/// Mapbox Harita Widget'ı
class MapboxHarita extends StatelessWidget {
  final double width;
  final double height;
  final Function(LatLng)? onMapTap;
  final Function(CameraPosition)? onCameraMove;
  final MapboxHaritaController controller;
  final String? selectedTool;
  final LatLng? currentLocation;
  final VoidCallback? onFenceModeDisabled;
  final Function(LatLng)? onFarmDesignRequest;

  const MapboxHarita({
    super.key,
    required this.width,
    required this.height,
    this.onMapTap,
    this.onCameraMove,
    required this.controller,
    this.selectedTool,
    this.currentLocation,
    this.onFenceModeDisabled,
    this.onFarmDesignRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Mapbox harita widget'ı buraya eklenecek
          // Şimdilik placeholder
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'Mapbox Harita',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Harita entegrasyonu yapılacak',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Konum göstergesi
          if (currentLocation != null)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
