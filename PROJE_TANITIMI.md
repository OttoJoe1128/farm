# 🌾 SmartFarm XR - Kapsamlı Proje Tanıtımı

## 📋 Proje Özeti

**SmartFarm XR**, gerçek zamanlı sensör verileriyle, harita tabanlı ve 3D/VR destekli modern çiftlik yönetim sistemidir. Proje, akıllı tarım teknolojilerini kullanarak çiftçilere kapsamlı bir dijital çiftlik deneyimi sunar.

## 🏗️ Mimari Yapı

### Frontend (Flutter)
- **Framework**: Flutter 3.5.4+ (Web/Mobile/Desktop)
- **State Management**: Riverpod + Freezed
- **Routing**: AutoRoute
- **Dependency Injection**: GetIt
- **Charts**: fl_chart
- **Maps**: Mapbox GL
- **Networking**: HTTP, WebSocket, MQTT Client
- **File Handling**: File Picker
- **Location**: Geolocator

### Backend (Python Flask + FastAPI)
- **API Framework**: Flask (GeoJSON işlemleri) + FastAPI (Ana sistem)
- **Database**: PostgreSQL + SQLite (GeoJSON cache)
- **Cache**: Redis
- **Geometric Operations**: Shapely, pyproj
- **Real-time**: WebSocket, MQTT
- **File Processing**: GeoJSON, TKGM entegrasyonu

### DevOps & Infrastructure
- **Containerization**: Docker + Docker Compose
- **Database**: PostgreSQL 15
- **Cache**: Redis 7
- **Database Management**: pgAdmin 4
- **Networking**: Custom bridge network

## 🚀 Ana Özellikler

### 1. 📊 Akıllı Dashboard
- **3 Sütunlu Layout**: Sol Panel (Sensörler) + Orta Panel (Harita) + Sağ Panel (Uyarılar)
- **Gerçek Zamanlı Veriler**: Toprak nemi, su seviyesi, enerji üretimi/tüketimi, hava sıcaklığı
- **Expandable Cards**: Detaylı bilgi görüntüleme
- **Responsive Design**: Tüm cihazlarda uyumlu

### 2. 🗺️ Gelişmiş Harita Sistemi
- **Mapbox GL Entegrasyonu**: Yüksek performanslı harita görüntüleme
- **GeoJSON Desteği**: Çoklu dosya yükleme ve birleştirme
- **TKGM Entegrasyonu**: Türkiye'deki parsel bilgilerine erişim
- **OSM Auto-Parcel**: OpenStreetMap verileriyle otomatik parsel oluşturma
- **Interactive Controls**: Zoom, pan, layer management

### 3. 🎯 Akıllı Parsel Yönetimi
- **Multi-GeoJSON Upload**: Birden fazla GeoJSON dosyası yükleme
- **Intelligent Merging**: Parselleri geometrik olarak birleştirme
- **Real-time Area Calculation**: Gerçek alan hesaplaması (m²)
- **Grid-based Design**: Tasarım panelinde grid sistemi
- **Coordinate Transformation**: EPSG:4326 → EPSG:3857 projeksiyon

### 4. 🎨 Tasarım Paneli
- **Direct Design Mode**: Çift tıklama ile direkt tasarım modu
- **Professional Tools**: Seç, taşı, döndür, ölçeklendir, kaydet
- **Grid Scaling**: Dinamik grid boyutu ayarlama
- **Real-time Preview**: Canlı tasarım önizleme
- **Export Functionality**: Tasarımları dışa aktarma

### 5. 🔧 Backend API Sistemi
- **RESTful API**: Flask tabanlı API endpoints
- **GeoJSON Processing**: Dosya yükleme, doğrulama, parsing
- **Database Management**: SQLite ile veri kalıcılığı
- **User Management**: Token tabanlı kullanıcı sistemi
- **CORS Support**: Cross-origin request desteği

## 🐳 Docker Altyapısı

### Docker Compose Servisleri
```yaml
services:
  postgres:     # PostgreSQL 15 Database
  redis:        # Redis 7 Cache
  backend:      # FastAPI Backend
  pgadmin:      # Database Management UI
```

### Port Yapılandırması
- **PostgreSQL**: 5432
- **Redis**: 6379
- **Backend API**: 8000
- **pgAdmin**: 5050
- **Flask GeoJSON API**: 5000

## 📁 Proje Yapısı

```
FARM/
├── api/                          # Flask GeoJSON API
│   ├── generateParcelByLatLng.py # Ana API dosyası
│   ├── smartfarm_data.db        # SQLite veritabanı
│   ├── uploads/                 # GeoJSON dosya yüklemeleri
│   └── venv/                    # Python virtual environment
├── backend/                     # FastAPI Backend
│   ├── api/                     # API endpoints
│   ├── core/                    # Core configuration
│   ├── database/                # Database schemas
│   ├── services/                # Business logic
│   └── Dockerfile               # Backend container
├── smartfarm_xr/               # Flutter Frontend
│   ├── lib/                    # Dart source code
│   │   ├── core/               # Core utilities
│   │   └── features/           # Feature modules
│   ├── web/                    # Web assets
│   └── pubspec.yaml            # Dependencies
├── docker-compose.yml          # Docker orchestration
└── SMARTFARM_XR_DEFTERI.md    # Proje dokümantasyonu
```

## 🔄 Veri Akışı

### 1. GeoJSON Upload Flow
```
Flutter → HTTP POST → Flask API → Validation → Database → Response
```

### 2. Parsel Merging Flow
```
Multiple GeoJSON → Shapely Union → Area Calculation → Database → Map Display
```

### 3. Real-time Data Flow
```
MQTT → Backend → WebSocket → Flutter → UI Update
```

## 🛠️ Kurulum ve Çalıştırma

### 1. Docker ile Tam Sistem
```bash
# Tüm servisleri başlat
docker-compose up -d

# Logları izle
docker-compose logs -f
```

### 2. Geliştirme Ortamı
```bash
# Backend (Flask)
cd api
source venv/bin/activate
python3 generateParcelByLatLng.py

# Frontend (Flutter)
cd smartfarm_xr
flutter run --device-id chrome
```

### 3. Veritabanı Yönetimi
- **pgAdmin**: http://localhost:5050
- **Credentials**: admin@smartfarm.com / admin123

## 📊 Teknik Detaylar

### API Endpoints
- `POST /api/uploadGeoJSON` - GeoJSON dosya yükleme
- `POST /api/mergeGeoJSONParcels` - Parsel birleştirme
- `GET /api/getGeoJSONParcels` - Parsel listesi
- `POST /api/clearGeoJSONParcels` - Parsel temizleme
- `GET /api/generateParcelByLatLng` - OSM parsel oluşturma

### Database Schema
```sql
-- Users table
CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    user_token TEXT UNIQUE,
    username TEXT,
    created_at TIMESTAMP
);

-- GeoJSON parcels table
CREATE TABLE geojson_parcels (
    id INTEGER PRIMARY KEY,
    user_token TEXT,
    parcel_id TEXT,
    polygon_data TEXT,
    area REAL,
    is_merged BOOLEAN,
    created_at TIMESTAMP
);
```

### Key Technologies
- **Geometric Processing**: Shapely, pyproj
- **Coordinate Systems**: EPSG:4326 (WGS84), EPSG:3857 (Web Mercator)
- **File Formats**: GeoJSON, JSON
- **Real-time**: WebSocket, MQTT
- **Maps**: Mapbox GL JS

## 🎯 Kullanım Senaryoları

### 1. Çiftlik Planlama
- GeoJSON dosyalarını yükle
- Parselleri birleştir
- Tasarım panelinde planla
- Grid sistemiyle ölçeklendir

### 2. Sensör Yönetimi
- Gerçek zamanlı veri izleme
- Uyarı sistemi
- Otomatik aksiyonlar
- Tarihsel analiz

### 3. Harita Analizi
- TKGM parsel sorguları
- OSM veri entegrasyonu
- Katman yönetimi
- Export/Import işlemleri

## 🔮 Gelecek Geliştirmeler

### Phase 1: MVP
- [x] Dashboard 3 sütun
- [x] Mapbox grid
- [x] GeoJSON upload/merge
- [x] Tasarım paneli
- [x] Docker altyapısı

### Phase 2: Beta
- [ ] Gerçek IoT cihaz entegrasyonu
- [ ] 3D ikonlar ve animasyonlar
- [ ] WebXR sahnesi
- [ ] Gelişmiş bildirimler
- [ ] Mobil uygulama

### Phase 3: Production
- [ ] SaaS çok kiracılı yapı
- [ ] AI/ML analitik
- [ ] Gelişmiş raporlama
- [ ] API marketplace
- [ ] Enterprise features

## 📈 Performans Metrikleri

- **Backend Response Time**: < 200ms
- **GeoJSON Processing**: < 1s (10MB dosya)
- **Map Rendering**: 60 FPS
- **Database Queries**: < 50ms
- **File Upload**: < 5s (16MB limit)

## 🔒 Güvenlik

- **CORS**: Cross-origin request kontrolü
- **File Validation**: GeoJSON format doğrulama
- **SQL Injection**: Parameterized queries
- **Token-based Auth**: User session management
- **File Size Limits**: 16MB upload limit

## 📞 Destek ve Dokümantasyon

- **Proje Defteri**: `SMARTFARM_XR_DEFTERI.md`
- **API Dokümantasyonu**: Backend swagger docs
- **Flutter Docs**: Inline code documentation
- **Docker Docs**: docker-compose.yml comments

---

**SmartFarm XR** - Modern tarımın dijital geleceği 🌱

*Son güncelleme: Eylül 2025*
