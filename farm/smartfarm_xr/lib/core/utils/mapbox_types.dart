/// Geçici Mapbox tipleri - mapbox_gl paketi Dart 3.5 ile uyumlu olmadığı için
/// Bu dosya geçici olarak oluşturuldu, mapbox_gl güncellendiğinde kaldırılacak

/// Konum koordinatları
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

/// Kamera pozisyonu
class CameraPosition {
  final LatLng target;
  final double zoom;
  final double bearing;
  final double tilt;

  const CameraPosition({
    required this.target,
    this.zoom = 14.0,
    this.bearing = 0.0,
    this.tilt = 0.0,
  });
}
