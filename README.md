# SmartFarm XR - Akıllı Çiftlik & Kadastro Yönetim Platformu

SmartFarm XR, tarımsal parselleri ve kadastro sınırlarını uydu görüntüsü üzerinde görselleştiren, parsel içinde dijital ikiz varlıkları (meyve ağaçları, su kuyuları, yapılar, IoT telemetri sensörleri ve güneş panelleri) yöneten, canlı IoT alarm/telemetri akışı izleyen ve iş emirleri oluşturan kurumsal web platformudur.

## Temel Özellikler

1. **İnteraktif Kadastro & Parsel Haritası**:
   - ESRI World Imagery uydu katmanı ve OpenStreetMap sokak görünümü.
   - Gerçek TKGM / GeoJSON parsel geometrisi (Edirne Merkez Bosna, Muğla Milas Çomakdağ ve özel yüklemeler).
   - Parsel sınırlarına kilitlenme (2.5m vertex snap) ve 2m metrik ızgara desteği.
   - Parsel dışına varlık eklenmesini engelleyen Ray-Casting poligon kontrolü.
   - Çiftlik içi mesafe ölçüm cetveli (metrik hesaplama).

2. **Dijital İkiz Varlık Yönetimi**:
   - Varlık Kütüphanesi: Ağaç, Yapı, Su Kuyusu, IoT Sensör, Güneş Paneli, Ölçüm.
   - Sürükle & Bırak ile harita üzerinde konum güncelleme.
   - Otomatik yerel metre koordinatları (`local_x_m`, `local_y_m`).

3. **Kapsamlı Dijital Varlık Kartı (Modal)**:
   - Genel bilgiler (Varlık kodu, notlar, fotoğraf).
   - Ağaç Künyesi (Tür, çeşit, yaş, dikim tarihi, anaç, sıra no, ağaç no).
   - Sağlık & Teşhis (Hastalık, zararlı, belirtiler, şiddet, tedavi planı).
   - IoT Parametreleri (Toprak nemi, gövde sıcaklığı, hava sıcaklığı, pH, EC, batarya, sinyal).
   - Bakım & Üretim (Sulama, ilaçlama, gübreleme, budama tarihleri, geçmiş ve beklenen verim).
   - Alarm Eşikleri (Min/Max nem ve sıcaklık değerleri).
   - Tek tıkla ilgili varlık adına iş emri talebi oluşturma.

4. **Saha ve Bakım İş Emirleri (Work Orders)**:
   - Durum filtreleme (Bekliyor, Devam Ediyor, Tamamlandı, İptal).
   - Öncelik yönetimi (Düşük, Normal, Yüksek, Acil).
   - Atanan personel ve son tamamlanma tarihi takibi.

5. **IoT Canlı Telemetri & Alarmlar**:
   - Dondurulmuş sözleşme: `ws.live.telemetry.v1`.
   - Gerçek zamanlı eşik aşımı tespitleri, alarm onaylama (Acknowledge) ve kapatma (Close).
   - Saha sensörü simülasyonu ve demo telemetri darbesi tetikleme.

6. **Admin & Denetim Paneli (RBAC & Audit Trail)**:
   - Rol bazlı kullanıcı yönetimi (Superadmin, Admin, Operator, Viewer).
   - Çiftlik ve parsel kütükleri.
   - Arama destekli denetim günlüğü (Audit Log).

7. **Otomatik Test Paketi (Vitest)**:
   - GIS uzamsal matematik ve EPSG:3857 Web Mercator dönüşüm doğrulaması.
   - Ray-Casting sınır kontrolü ve snap testleri.
   - Faz 2 backend API yanıt zarfı (`farm.v1.1.phase2`) sözleşme doğrulaması.
   - Çakışma çözümleme politikası (`latest_timestamp_wins`) testleri.

## Geliştirme ve Test

```bash
# Bağımlılıkları yükle
npm install

# Geliştirme sunucusunu başlat (Port 3000)
npm run dev

# Otomatik test paketini çalıştır
npm test

# Üretim derlemesi
npm run build
```
