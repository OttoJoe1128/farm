/// SmartFarm XR Mapbox Konfigürasyonu
/// Harita servisleri için gerekli ayarlar
class MapboxConfig {
  // Private constructor - singleton pattern
  MapboxConfig._();
  
  // Mapbox Access Token (Production'da environment variable'dan alınacak)
  static const String accessToken = 'pk.eyJ1IjoiZHJhZ29zbGlzcyIsImEiOiJjbWV3dDhudDUwczByMm1zaHhjNmo3bTQxIn0.slZRFqawbHmuAphq621qAw';
  
  // Varsayılan harita stili
  static const String defaultStyle = 'mapbox://styles/mapbox/dark-v11';
  
  // Varsayılan konum (İstanbul koordinatları)
  static const double defaultLatitude = 41.0082;
  static const double defaultLongitude = 28.9784;
  static const double defaultZoom = 10.0;
  
  // Harita sınırları
  static const double minZoom = 5.0;
  static const double maxZoom = 18.0;
  
  // Grid boyutları
  static const double gridSize = 32.0;
  static const double gridOpacity = 0.3;
  
  // Harita katmanları
  static const List<String> mapLayers = [
    'satellite',
    'streets',
    'outdoors',
    'light',
    'dark',
    'satellite-streets',
  ];
  
  // IoT cihazları için harita sembolleri
  static const Map<String, String> deviceSymbols = {
    'sensor': '📍',
    'camera': '📷',
    'valve': '🚰',
    'pump': '⛽',
    'weather': '🌤️',
    'energy': '⚡',
    'animal': '🐄',
  };
  
  // Harita kontrolleri
  static const bool enableCompass = true;
  static const bool enableZoomControls = true;
  static const bool enableLocationButton = true;
  static const bool enableFullscreenButton = true;
}
