# 🚜 SmartFarm XR - Geliştirme Yol Haritası

Bu belge, projenin "Dijital İkiz" ve "Akıllı Çiftlik Yönetimi" dönüşüm sürecini takip eder.

## 🟢 FAZ 1: Temel GIS ve Görüntüleme (TAMAMLANDI)
- [x] Backend: GeoJSON/KML dosya okuma ve parse etme motoru (GisService).
- [x] Backend: Koordinat sistemleri arası dönüşüm (WGS84 -> Metrik).
- [x] Backend: Varlık sınıflandırma algoritması (Tarla vs Yapı vs Ağaç).
- [x] Frontend: Harita entegrasyonu (Flutter Map).
- [x] Frontend: GeoJSON verisini harita üzerinde çizme.
- [x] Frontend: Kamera odaklama ve otomatik zoom (Auto-Fit).
- [x] Frontend: Hatalı veri tiplerine karşı "Robust Parser" (Çökme önleyici).

## 🟢 FAZ 2: Hassas Planlama ve Izgara Sistemi (TAMAMLANDI)
- [x] Frontend: Zoom seviyesine duyarlı "Dinamik Grid (Izgara)" katmanı.
- [x] Frontend: Mühendislik Modu (Grid Rengi ve Görünürlük Ayarı).
- [ ] Frontend: Metre/Dönüm ölçüm araçları (Cetvel).
- [ ] Frontend: Gridlerin dünya koordinatlarına (Lat/Lng) kilitlenmesi.

## 🟡 FAZ 3: Etkileşimli Editör (MEVCUT AŞAMA)
"Sıkıcı Paneller" yerine "Sürükle-Bırak" sistemi.
- [x] Frontend: Alt menüde "Varlık Kütüphanesi" (Asset Dock) tasarımı. (TAMAMLANDI ✅)
- [x] Frontend: Sürükle-Bırak (Drag & Drop) ve Koordinat Hesaplama Matematiği. (TAMAMLANDI ✅)
- [ ] Backend: Varlıkların Parent-Child (Tarla -> Ağaç) ilişkisinin veritabanı şeması. (SIRADAKİ ADIM 🎯)
- [ ] Frontend: Seçili varlığı silme, taşıma, döndürme özellikleri.
- [ ] Backend: Yeni eklenen varlıkların veritabanına kaydedilmesi (Persistence).

## 🟣 FAZ 4: Akıllı Analiz ve Otomasyon
- [ ] Backend: Google Earth Engine / OpenCV ile uydu görüntüsünden "Otomatik Varlık Tespiti" (Draft Mode).
- [ ] Frontend: Yapay zeka önerilerini "Onayla/Reddet" arayüzü.

## 🔵 FAZ 5: 3D ve Simülasyon (IMMERSION)
- [ ] Frontend: 2D Poligonları 3D küplere dönüştüren görsel motor (Extrusion).
- [ ] Frontend: First Person (Yürüme) Modu entegrasyonu.
- [ ] IoT: Varlıklara canlı sensör verisi bağlama (MQTT Entegrasyonu).

---
**Son Güncelleme:** $(date)
