# SmartFarm XR: Web Yeniden Yapilandirma ve Test Plani

SmartFarm XR platformunu Node 22 çalışma ortamına uygun, port 3000 üzerinde çalışan tam özellikli bir React + Vite uygulaması olarak ayağa kaldırma ve hem backend kontratlarını hem de frontend bileşenlerini kapsayan otomatik test paketini kurma planı.

## User Review & Critical Decisions

> [!IMPORTANT]
> Kullanıcı ile 1. Aşama soru-cevap sürecinde teyit edilen ve onaylanan kritik kararlar:

- **Otomatik Test Kapsamı**: Kullanıcı onayı doğrultusunda hem backend FastAPI API/kontratları (`/api/v1/*`, `/ws/live`, GIS, IoT, Work Orders, Conflict Policy) hem de React frontend bileşenleri için uçtan uca doğrulama testleri yazılacaktır.
- **Arayüz Mimarisi**: Flutter SDK'nın kurulu olmaması nedeniyle Flutter XR uygulamasındaki tüm iş mantığı, harita araçları, dijital kartlar ve yönetim özellikleri modern React + TypeScript + Vite + Tailwind CSS yığınına dönüştürülecektir.
- **Orijinal Dosyaların Korunması**: `github-import-rewrite` yönergeleri uyarınca yeni React uygulaması derlenip `compile_applet` ile doğrulanana kadar orijinal kaynak kodlar silinmeyecektir.

---

## 1. Overview & Core Concept

- **Ne Yapıyor**: Çiftçiler ve tarım işletmeleri için kadastro parsel verilerini (GeoJSON/KML/TKGM) harita ve uydu katmanlarında görselleştiren, parsel sınırları içinde dijital ikiz varlıkları (ağaç, yapı, su kuyusu, IoT sensör, güneş enerjisi, ölçüm araçları) yöneten, canlı IoT telemetrisi izleyen ve iş emirleri oluşturan web platformu.
- **Kullanıcı Kitlesi**: Çiftlik sahipleri, tarım mühendisleri, saha denetçileri ve operasyon yöneticileri.
- **Temel Değer**: Sahadan toplanan coğrafi veriler ile ofisteki yönetim planlamasını tek merkezde toplayarak parsele dayalı dijital ikiz ve bakım süreçlerini hatasız yönetmek.

---

## 2. User Experience & Visual Design

### Temel Kullanıcı Akışları
1. **Harita & Parsel Görüntüleme**: Kullanıcı sisteme girer; hazır Edirne/Milas kadastro parselleri otomatik yüklenir veya bilgisayardan `.geojson` / `.json` yüklenir. Harita parsele otomatik zoom yapar.
2. **Uydu Katmanı & Hibrit Görünüm**: ESRI / Google / Uydu katmanı parsel sınırlarına maskelenerek veya alt katman olarak açılır; önbellek ve tazelik bilgisi gösterilir.
3. **Dijital İkiz Varlık Kütüphanesi (Toolbar)**: Ekranın altındaki şık araç çubuğundan Ağaç, Yapı, Su Kuyusu, IoT Sensör, Güneş Paneli veya Ölçüm Cetveli seçilir. Parsel içine tıklandığında otomatik snap ve yerel metre koordinatlarıyla (`local_x_m`, `local_y_m`) varlık yerleştirilir.
4. **Dijital Varlık Kartı & Modal**: Herhangi bir varlığa tıklandığında Genel Bilgiler, Ağaç Künyesi, Sağlık Durumu, IoT Parametreleri (toprak nemi, sıcaklık, pH, EC), Bakım Geçmişi ve Alarm Eşikleri düzenlenebilir, anında iş emri oluşturulabilir.
5. **İş Emirleri & KPI Paneli**: Açık iş emirleri, toplam varlık sayısı, aktif alarmlar ve canlı telemetri üst bilgi barında gerçek zamanlı gösterilir.
6. **Admin Paneli**: Kullanıcı yetkilendirme, çiftlik yönetimi ve denetim logları (audit log) incelenebilir.

### Görsel Tasarım & Tema
- **Aesthetic Direction**: Temiz, modern, endüstriyel tarım SaaS paneli (SaaS Dashboard yönergelerine tam uyumlu, anti-slop, sıfır pill badges, yüksek yoğunluklu okunabilirlik).
- **Renk Paleti**:
  - Zemin: Koyu arduvaz ve nötr arka plan (`#0F172A`, `#1E293B`, `#020617`).
  - Varlık Renkleri: Ağaç (Yeşil `#22C55E`), Yapı (Kahve/Amber `#F59E0B`), Su Kuyusu (Mavi `#38BDF8`), IoT Sensör (Turuncu `#FB923C`), Güneş Enerjisi (Sarı `#FACC15`), Ölçüm (Cyan `#06B6D4`).
  - Statü ve Vurgu: Nominal/Normal (`#10B981`), Uyarı (`#F59E0B`), Kritik Alarm (`#EF4444`).
- **Tipografi**: Display ve başlıklar için `Plus Jakarta Sans`, veri değerleri, koordinatlar ve metrikler için monospace tabular figures (`JetBrains Mono`, `tabular-nums`).

---

## 3. Key Product Decisions & Trade-Offs

- **Harita Kütüphanesi Seçimi**: Leaflet + React-Leaflet + Canvas
  - *Gerekçe*: Harici API anahtarı zorunluluğu olmadan OpenStreetMap, ESRI World Imagery ve özel kadastro GeoJSON katmanlarını yüksek hızda, sıfır yapılandırma sorunu ile render eder.
  - *Alternatifler*: Mapbox GL JS değerlendirildi ancak token kısıtlamaları ve konteyner içi proxy sorunları nedeniyle açık kaynak Leaflet tercih edildi.
- **Veri Kalıcılığı & Offline Sync**:
  - *Gerekçe*: `localStorage` + IndexedDB önbelleği ile çevrimdışı işlem kuyruğu (`pending_ops`) tutulur. Backend erişilebilir olduğunda `/api/v1/gis/sync` ve `/api/v1/gis/replace-map` üzerinden iki yönlü senkronizasyon yapılır.
- **Otomatik Test Mimarisi**:
  - *Gerekçe*: Frontend için Vitest + Testing Library (bileşen ve harita etkileşimleri), Backend için Node test runner/pytest ile kontrat testleri (`/api/v1/contracts`, fault lifecycle, IoT telemetry, conflict policy).

---

## 4. Technical Architecture & Data Strategy

### Mimari Diyagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SMARTFARM XR - REACT CLIENT (PORT 3000)             │
│                                                                        │
│  ┌───────────────────────┐  ┌───────────────────────────────────────┐  │
│  │ Top Bar & KPI Strip   │  │ Interactive Map Viewport (Leaflet)    │  │
│  │ · Parseller / Uydu    │  │ · GeoJSON Parcels & Boundary Snap     │  │
│  │ · İş Emirleri / Alarm │  │ · Digital Twin Point/Polygon Layers   │  │
│  │ · Admin & Profil      │  │ · Distance Measure & Local Grid (2m)  │  │
│  └───────────────────────┘  └───────────────────────────────────────┘  │
│  ┌───────────────────────┐  ┌───────────────────────────────────────┐  │
│  │ Varlık Kütüphanesi    │  │ Varlık Detay & Dijital Kart Modalı    │  │
│  │ · Ağaç, Yapı, Su, IoT │  │ · Ağaç / Sağlık / IoT / Bakım         │  │
│  │ · Enerji, Cetvel      │  │ · İş Emri Talebi & Alarm Eşikleri     │  │
│  └───────────────────────┘  └───────────────────────────────────────┘  │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                     HTTP REST / JSON & WS / Live
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   BACKEND API & DATA SERVICES                          │
│                                                                        │
│  · GIS & Parsel Yönetimi (/api/v1/gis/*, /api/v1/field/ingest)         │
│  · Uydu Çekim & Maskeleme (ESRI / XYZ Tile Engine)                     │
│  · IoT Telemetri & Alarmlar (/api/v1/iot/*, WS /ws/live)               │
│  · İş Emirleri & Bakım Takibi (/api/v1/work-orders)                    │
│  · Yetkilendirme & Denetim Kayıtları (/api/v1/auth/*, audit_log)       │
└────────────────────────────────────────────────────────────────────────┘
```

### Veri Modelleri
- **Parcel**: GeoJSON Polygon / MultiPolygon, kadastro alan tipi, malik, ada/parsel numarası.
- **Canonical Asset**: `asset_id`, `name`, `type` (`Point` / `Polygon`), `geometry`, `style` (renk, ikon), `properties` (`local_x_m`, `local_y_m`, `digital_card`, `meta`, `timestamps`, `audit_log`).
- **Digital Card**: `genel` (notlar, foto), `agac` (tür, çeşit, yaş, sıra no), `saglik` (hastalık, zararlı, şiddet), `iot` (toprak nemi, sıcaklık, ph, pil), `bakim` (sulama, gübreleme, budama), `alarm` (min/max eşikler).
- **Work Order**: `work_order_id`, `asset_id`, `title`, `description`, `priority`, `status`, `assignee`, `created_at`.
- **IoT Event / Alert**: `schema_version` (`ws.live.telemetry.v1`), `device_id`, `metrics`, `alerts`, `measured_at`.

### Otomatik Test Paketi Adımları
1. **API & Kontrat Testleri**:
   - `GET /api/v1/contracts`: Kontrat sürümü ve şema doğrulaması.
   - `POST /api/v1/gis/sync` & `POST /api/v1/gis/update-asset-by-id`: Conflict policy (`latest_timestamp_wins`, `incoming_wins`, `existing_wins`) testleri.
   - `POST /api/v1/iot/telemetry`: Eşik aşımında alarm üretimi ve canlı event formatı doğrulaması.
   - `POST /api/v1/work-orders`: İş emri oluşturma, güncelleme ve KPI yansıması testleri.
2. **Frontend Arayüz Testleri (Vitest)**:
   - Parsel GeoJSON yükleme ve harita render testi.
   - Araç çubuğundan varlık seçimi ve harita üzerine snap ile yerleştirme testi.
   - Dijital kart veri düzenleme ve kaydetme testi.
   - Çevrimdışı işlem kuyruğu (`pending_ops`) senkronizasyon testi.
