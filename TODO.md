# TODO

Tek yapılacaklar listesi. Bir iş bitince `[x]` işaretle, yeni iş ekle; başka yol haritası dosyası tutma.

Durum: `[x]` tamam, `[~]` kısmen, `[ ]` açık.

## P0: Parsel içine varlık ekleme (çalışır hale getir)

- [x] Parsel içi / dışı tespiti (`isPointInPolygon`, `findParcelContainingPoint`)
- [x] Araç seçiliyken parsel tıklaması varlık eklesin (`stopPropagation` yalnızca araç/taşıma/düzenleme yokken)
- [x] Sınır dışı tıklamada uyarı
- [ ] Tarayıcıda uçtan uca elle doğrula (Edirne ve Milas parselleri, her araç tipi, Vercel önizlemesinde)
- [ ] Parsel seçili değilken araç seçilirse net yönlendirme mesajı

## P1: Snap ve veri modeli

- [x] Izgara ve köşe kenetlenmesi (`snapToParcelOrGrid`, `computePolygonClippedGrid`, `buildParcelGridCellSizes`)
- [x] `CanonicalAsset.parcel_id` + `getParcelId` + backend `Asset.parcel_id`
- [ ] Taşıma sırasında varlığın kendi parselini (`parcel_id`) esas al, seçili parseli değil
- [ ] Eski `localStorage` kayıtlarına `parcel_id` göç/yedekleme (parsel geometrisine göre doldur)
- [ ] Çizgisel varlıklarda (`su_borusu`, `elektrik_kablo`) bitiş noktası da parsel içinde kalsın (şu an sabit ofsetle üretiliyor)

## P2: Çizim araçları

- [ ] Hat çizimi: çok noktalı polyline, tıkla-ekle / çift tıkla-bitir, her nokta parsel içinde
- [ ] Alan (poligon) varlıkları çizimi (`Polygon` tipi zaten modelde var)
- [ ] Düğüm sürükleyerek hat/alan düzenleme
- [ ] Geri al / yinele
- [ ] Hat uzunluğu ve alan değerlerinin otomatik hesaplanması

## P3: Backend entegrasyonu

- [ ] API istemcisi (`src/services/api.ts`) + `VITE_API_URL` ortam değişkeni
- [ ] Giriş / token yönetimi (`/api/v1/auth/*`), token'ı güvenli sakla
- [ ] Varlıkları `/api/v1/gis/*` ile yükle, ekle, güncelle, sil (`asset_id` esleme kuralı sabit)
- [ ] Çevrimdışı işlem kuyruğu ve `/api/v1/gis/sync` (başarılı olunca kuyruğu temizle, retry politikası)
- [ ] Canlı telemetri: `WS /ws/live` (auth mesajı, exponential backoff, heartbeat, `schema_mismatch` yönetimi)
- [ ] Hata zarfı (`error_code`, `message`, `details`) için tek parser
- [ ] Backend'i Vercel dışında barındır (Docker/VM), `CORS_ORIGINS` ayarla, HTTPS zorunlu
- [ ] Parsel listesi/yükleme (GeoJSON/TKGM) backend ile kalıcı

## P4: Test ve kalite

- [~] GIS birim testleri (Vitest, 10 test) ve sözleşme testleri
- [ ] Bileşen testleri (Testing Library): araç seç → parsel içine ekle → dışına eklemeyi reddet
- [ ] Backend API test kapsamı: tüm kritik uçlar (fault, IoT yaşam döngüsü, sync) için başarılı/hata senaryoları
- [ ] Web + backend uçtan uca smoke testi (telemetri → WS → arayüz rozeti, arıza çöz → `open_fault_count` azalır)
- [ ] CI'a Vercel önizleme kontrolü

## Güvenlik ve altyapı

- [ ] Git remote URL'sindeki GitHub token'ını iptal et (`ghp_...` URL içinde açık durumda), SSH veya credential helper kullan
- [ ] `docker-compose.yml` içinde `CORS_ORIGINS` varsayılanı `*`: production'da kısıtla
- [ ] Release kontrol listesi (tek checklist)
