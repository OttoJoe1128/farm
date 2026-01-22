# SmartFarm XR – Proje Defteri

Bu dosya; yol haritası, mimari, görev listesi ve ilerleme kayıtlarının tek kaynağıdır.

## 1) Proje Özeti
- Amaç: Gerçek zamanlı sensör verileriyle, harita tabanlı ve 3D/VR destekli çiftlik deneyimi.
- Bileşenler: Dashboard (Sol/Orta/Sağ), Harita (Mapbox/QGIS), IoT (MQTT/WebSocket), Otomasyon, Bildirimler, VR/AR.

## 2) Mimari (Yüksek Seviye)
- Frontend: Flutter (Web/Mobile), Riverpod, Freezed, AutoRoute, getIt, fl_chart, mapbox_gl.
- Backend: FastAPI (REST + WebSocket), Postgres(+TimescaleDB), Redis, MQTT Broker (EMQX/Mosquitto).
- Akış: MQTT → Backend (Rule Engine) → Event Bus → WebSocket → Flutter UI.

### Flutter Modül Yapısı
- core/
- domain/
- data/
- features/
  - dashboard/
  - map/
  - iot/

## 3) Yol Haritası
- MVP: Dashboard 3 sütun, Mapbox grid, canlı mock akış, kural motoru, uyarılar
- Beta: Gerçek cihaz/GPS, 3D ikonlar, animasyonlu grid, WebXR sahnesi, bildirimler
- Ürünleşme: SaaS çok kiracılı yapı, gelişmiş analitik/AI, mobil uygulama

## 4) Kurallar
- Clean Architecture, SOLID, repository pattern
- Riverpod + Freezed UI state
- Türkçe kod ve dokümantasyon; adlandırma standartları
- Yeni dosya öncesi varlık kontrolü; mevcut yapıyı bozmadan ilerleme

## 5) Güncel Görev Listesi
- [x] Figma bileşen kütüphanesini ve görsel dilini tanımla (id: figma-design-system)
- [x] Flutter projesi iskeletini kur ve temel bağımlılıkları ekle (id: flutter-skeleton-setup)
- [x] Dashboard sol/orta/sağ paneller için widget ağacını uygula (id: dashboard-ui)
- [ ] Domain modellerini, Freezed durumlarını ve Riverpod provider'larını tanımla (id: domain-and-state)
- [ ] Harita modülünü (Mapbox) ve grid sahnesini prototiple (id: map-module)
- [ ] MQTT/WebSocket mock veri hattını kur ve canlı veri akışını simüle et (id: realtime-mock-stream)
- [x] Merkezi proje defteri dosyasını oluştur ve düzenli güncelle (id: project-ledger)

## 6) Tasarım Sistemi (Figma)
- Renk: Kart/* (pastel), Uyari/* (sarı/turuncu/kırmızı), Grid/Mor, Nötr/*
- Metin: Kart/Başlık 18B, Değer 20SB; Uyarı/Başlık 18B, Metin 14R
- Bileşenler: BilgiKarti, UyariKarti, HaritaSembol, IconBar
- Frame: 1440×900, 3 sütun; Orta panel grid overlay

### 6.1 Icon Bar (Harita için 3D İllüstratif Set)
- Konum: Harita panelinin sol üstünde dock, hover ile genişler.
- İçerik Grupları:
  - Sensörler: Toprak, Su, Enerji, Hava, Hayvan Aktivitesi
  - Cihazlar: Pompa, Yem Makinesi, Solar, Depo, Drone
  - Katmanlar: Ağaçlar, Su Yolları, Parseller, IoT, Uyarılar
- Varyantlar: `boyut = compact|expanded`, `tema = light|dark`, `durum = normal|aktif|kritik`
- 3D Stil: Yumuşak gölgeli, PBR benzeri ışık; ikon başına 2 ton degrade + hafif specular.
- Etkileşim: Hover → tooltip + parıltı; Click → ilgili katman/cihaz seçimi; Shift+Click → çoklu seçim.

#### 6.1.A Gerçekçi Icon Bar – Örnek Kompozisyon
- Varsayılan 5 ikon: Toprak, Su, Enerji, Pompa, Uyarı
- Boyutlar: `compact=40×40`, `expanded=56×56` (canvas), ikon safe-area 84%
- Malzeme & Işık:
  - Base color: çift degrade (üstten alta), subtle noise 2–3%
  - Roughness 0.35–0.45, Metalness 0.05–0.1 (plastik/kompozit hissi)
  - Üst sol 45° key light, alt sağ 10% fill; Ambient occlusion hafif
  - Kenar vurgusu: 1px inner highlight, 12% opacity
- Durum renkleri:
  - normal: brand ton
  - aktif: brand ton + dış parıltı 8% + 1px dış stroke
  - kritik: kırmızı 600 tabanı, titreşimli glow 12%
- Örnek konumlandırma (compact):
  - [Toprak][Su][Enerji][Pompa][Uyarı]  → spacing 8px, padding 12px, radius 12

Örnek ikon özellikleri (tasarım değişkenleri):
```json
{
  "icons": [
    {"id": "toprak", "label": "Toprak", "symbol": "soil" , "state": "normal", "color": "#8BC34A", "tooltip": "%45 nem", "material": {"roughness": 0.4, "metalness": 0.08}},
    {"id": "su",     "label": "Su",     "symbol": "water", "state": "aktif",  "color": "#29B6F6", "tooltip": "%70 seviye", "material": {"roughness": 0.38, "metalness": 0.06}},
    {"id": "enerji", "label": "Enerji", "symbol": "solar", "state": "normal", "color": "#FFD54F", "tooltip": "5 kW üretim", "material": {"roughness": 0.42, "metalness": 0.05}},
    {"id": "pompa",  "label": "Pompa",  "symbol": "pump",  "state": "aktif",  "color": "#26A69A", "tooltip": "Açık", "material": {"roughness": 0.45, "metalness": 0.1}},
    {"id": "uyari",  "label": "Uyarı",  "symbol": "alert", "state": "kritik", "color": "#EF5350", "tooltip": "Nem kritik %30", "material": {"roughness": 0.35, "metalness": 0.05}}
  ],
  "variants": {"size": ["compact", "expanded"], "theme": ["light", "dark"], "state": ["normal", "aktif", "kritik"]}
}
```

Export rehberi:
- SVG (ikon kontur) + PNG@2x/@3x (ışık/gölge efektleri korunur)
- Sprite sheet: 56px grid, 8px spacing, dark ve light temalar ayrı
- Adlandırma: `icon/[tema]/[id]_[durum]_[size].png` (ör: `icon/dark/pompa_aktif_compact.png`)

### 6.2 Açılır Kart Davranışı
- Kart türleri: BilgiKarti (sol), UyariKarti (sağ)
- Durumlar: `collapsed` (özet), `expanded` (detay), `alert-overlay` (kritik popover)
- Animasyon: 180–220ms ease-in-out; height ve opacity birlikte; ikon mikro-bounce 1.05 scale
- İçerik Hiyerarşisi:
  - Özet: başlık + değer/şiddet rozeti
  - Detay: mini grafik (son 24s), eşik/kurallar, son güncelleme zamanı, aksiyon butonları
- Renk Uyumu: Gönderdiğin görsel paletine bağlı; doygunluk +10%, kontrast +15% ile geliştirilmiş

## 7) Riskler
- Mapbox lisans/perf; canlı akış reconnect; VR/AR kapsamı MVP’de sınırlı

## 8) Değişiklik Günlüğü
- v0.1.0 — Defter oluşturuldu ve başlangıç içerikleri yazıldı.
- v0.2.0 — Flutter Web projesi kuruldu, temel tasarım sistemi implement edildi.
  - ✅ Renk paleti (AppColors): Kart/*, Uyari/*, Grid/Mor, Nötr/* renkleri
  - ✅ Tipografi sistemi (AppTextStyles): Inter font, 12-32px scale, weight varyantları
  - ✅ Spacing sistemi (AppSpacing): 4px base unit, component spacing kuralları
  - ✅ Tema sistemi (AppTheme): Dark theme, button, card, input stilleri
  - ✅ Dashboard layout: 3 sütun (Sol Panel + Harita + Sağ Panel)
  - ✅ Sol Panel: BilgiKarti (Toprak, Su, Enerji, Hava) - expandable
  - ✅ Orta Panel: HaritaPaneli (Grid background + Icon Bar + Map controls)
  - ✅ Sağ Panel: UyariKarti (Kritik durumlar) - expandable + aksiyon butonları
  - ✅ Animasyonlar: Height, icon scale, pulse (kritik uyarılar için)
  - ✅ Icon Bar: 5 ikon (Toprak, Su, Enerji, Pompa, Uyarı) - hover tooltip
  - ✅ Grid sistemi: CustomPainter ile 32×32 px mor grid
  - ✅ Responsive layout: 320px sol/sağ panel, orta panel flexible
- v0.2.1 — Linux desktop development environment kuruldu.
  - ✅ CMake kurulumu (3.28.3)
  - ✅ Ninja build tool kurulumu
  - ✅ Clang C++ compiler kurulumu (LLVM 18)
  - ✅ Build tools hazır, proje çalıştırılabilir

---
Bu dosya proje boyunca tek gerçek kaynaktır.
