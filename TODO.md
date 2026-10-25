# TODO

Tek yapılacaklar listesi. Bir iş bitince `[x]` işaretle, yeni iş ekle; başka yol haritası dosyası tutma.
Her maddeden önce: o konuda daha önce geliştirme var mı, çakışan dosya var mı kontrol edilir; çalışan (pozitif) davranışlar korunur.

Durum: `[x]` tamam, `[~]` kısmen, `[ ]` açık.

## Mevcut durum analizi (2026-10-25)

**Arayüz ve backend birbirine bağlı değil.** `src/` içinde `fetch`, `WebSocket` ya da `VITE_*` ortam değişkeni yok. Tüm veri (parseller, varlıklar, iş emirleri) tarayıcıda `localStorage` anahtarı `smartfarm_state_v2` içinde. Sonuçları:

- Veri yalnızca o tarayıcıda ve o cihazda durur. Site verisi silinirse ya da başka cihazdan girilirse her şey kaybolur/görünmez.
- Giriş (login) ekranı yok. Backend'in tüm uçları token ister, yani bağlanmadan önce giriş akışı şart.
- IoT telemetri, alarmlar, "Saha Aktar" ve admin paneli arayüzde simüle ediliyor; gerçek veri akışı yok.
- Parsel GeoJSON yükleme tamamen tarayıcıda (`FileReader`) çalışır, backend gerekmez: Vercel'de de çalışması beklenir. Geçmişteki 4 gerçek örnek dosyayla (Edirne, Milas/TKGM, test) aynı süzme mantığı Node'da denendi; 3'ü TKGM alanlarıyla (`ParselNo`, `Ada`...) kabul edildi. Tarayıcıda/Vercel'de elle henüz denenmedi.

**Backend (FastAPI)** hazır ve testli, ancak:
- Varsayılan depolama JSON dosyası; geçici (ephemeral) sunucuda her yeniden başlatmada silinir. Kalıcılık için PostGIS seçeneği hazır (`STORAGE_BACKEND=postgis`).
- `/api/v1/gis/upload-map` `geopandas` ister; `requirements.txt` içinde `geopandas`, `opencv`, `numpy`, `shapely` birlikte olduğu için kurulum çok büyük. Vercel fonksiyon boyut sınırına sığmaz; WebSocket (`/ws/live`) da Vercel'de çalışmaz. Backend'in ayrı barındırılması gerekir.
- `CORS_ORIGINS` varsayılanı `*`.

**Vercel:** arayüz (statik Vite çıktısı) için uygundur. Backend için uygun değildir.

## Ücretsiz demo barındırma seçenekleri (backend için)

Koşullar Render dokümanından (render.com/docs/free) doğrulandı; diğerleri için güncel koşulları kayıt öncesi kontrol et.

| Seçenek | Uygunluk | Dikkat |
|---|---|---|
| **Render** Free Web Service + Docker (`backend/Dockerfile`) | WebSocket destekler, HTTPS, özel domain. En kolay başlangıç | 15 dk trafiksiz kalınca uyur, uyanması ~1 dk. Dosya sistemi geçicidir: JSON depolama kullanma. Aylık 750 saat |
| **Render** Free Postgres | Sunucuyla aynı yerde | 30 gün sonra süresi dolar, 1 GB, yedek yok. Demo için tamam, kalıcı için olmaz |
| **Neon** Free Postgres | PostGIS eklentisi destekleniyor (`CREATE EXTENSION postgis`) | Backend'i `STORAGE_BACKEND=postgis` + `DATABASE_URL` ile bağlarız. Kalıcı veri için Render DB yerine bunu öneririm |
| **Supabase** Free Postgres | PostGIS var | Hareketsizlikte proje duraklatılabilir |
| Fly.io, Koyeb, Railway | Docker çalıştırır | Ücretsiz katmanları sık değişiyor; kullanmadan önce güncel koşulları doğrula |

Önerilen demo mimarisi: **arayüz Vercel (mevcut domain) + backend Render (Docker) + veritabanı Neon (PostGIS)**. İlk istek gecikmesi (uyku) demoda kabul edilebilir; yönetici gösterimi öncesi bir kez "uyandırmak" yeterli.

## P0: Veri güvenliği ve yükleme doğruluğu (hemen)

- [x] Parsel içi/dışı tespiti, araç seçiliyken tıklamayla varlık ekleme, sınır dışı uyarısı
- [ ] **Parsel kimliği çakışması:** `ParselNo`/`Ada` olmayan GeoJSON parselleri (ör. `name`, `owner` alanlı dosyalar) hepsi `0/0` kimliği alıyor ve `areSameParcel` hepsini aynı parsel sayıyor. Kimlik: `properties.parcel_id` → `Ada/ParselNo` → yoksa geometriden üretilen kararlı özet (hash). Yükleme sırasında her parsele `parcel_id` yaz
- [ ] **KML:** dosya seçici `.kml` kabul ediyor ama içerik JSON diye okunuyor, hata veriyor. Ya KML desteği ekle ya da `.kml`'i kabul listesinden çıkar
- [ ] **Yükleme doğrulaması:** `else if (json.features)` dalı Polygon olmayan/Feature olmayan nesneleri kabul ediyor; koordinatların WGS84 aralığında (boylam ±180, enlem ±90) olduğunu kontrol et. TKGM'nin projeksiyonlu (metre) koordinatlarında anlaşılır hata ver
- [ ] **Yinelenen yükleme:** aynı dosya art arda yüklenince parseller çoğalıyor; aynı `parcel_id` varsa güncelle/uyar
- [ ] **`localStorage` kotası (~5 MB):** kayıt hatası sessizce `console.warn`'a gidiyor. Büyük parsel dosyalarında veri kaybolur. Kullanıcıya görünür uyarı ver; yedek olarak "dışa aktar / içe aktar (JSON)" ekle
- [ ] Tarayıcıda uçtan uca elle doğrula: Vercel'de GeoJSON yükle → parsele zoom → her araç tipiyle varlık ekle → sayfayı yenile
- [ ] Parsel seçili değilken araç seçilirse net yönlendirme mesajı

## P1: Snap ve veri modeli

- [x] Izgara ve köşe kenetlenmesi (`snapToParcelOrGrid`, `computePolygonClippedGrid`, `buildParcelGridCellSizes`)
- [x] `CanonicalAsset.parcel_id` + `getParcelId` + backend `Asset.parcel_id`
- [ ] Taşıma sırasında varlığın kendi parselini (`parcel_id`) esas al, seçili parseli değil
- [ ] Eski `localStorage` kayıtlarına `parcel_id` göçü (parsel geometrisine göre doldur)
- [ ] Çizgisel varlıklarda (`su_borusu`, `elektrik_kablo`) bitiş noktası da parsel içinde kalsın (şu an sabit ofsetle üretiliyor, parsel dışına taşabilir)

## P2: Backend'i canlıya al ve bağla

Önce barındırma kararı (yukarıdaki tablo), sonra:

- [ ] Backend'i Render'a (Docker) kur; `SECRET_KEY`, `ENVIRONMENT=production`, `CORS_ORIGINS=<vercel domain>`, `DEFAULT_ADMIN_EMAIL/PASSWORD` ayarla
- [ ] Neon'da PostGIS veritabanı aç, `STORAGE_BACKEND=postgis` + `DATABASE_URL`; `/health` ile doğrula
- [ ] Vercel'de `VITE_API_URL` ortam değişkeni; `src/services/api.ts` istemcisi
- [ ] Giriş / kayıt ekranı, token'ı güvenli sakla, yenileme (`/api/v1/auth/refresh`)
- [ ] Varlıkları `/api/v1/gis/*` ile yükle/ekle/güncelle/sil (`asset_id` eşleme kuralı sabit). `localStorage` çevrimdışı önbellek olarak kalsın (mevcut davranışı bozma)
- [ ] Parselleri backend'e kaydet (kalıcı); `upload-map` bağımlılık yükünü azaltmayı değerlendir (geopandas yerine saf `shapely`/`json`)
- [ ] Çevrimdışı işlem kuyruğu + `/api/v1/gis/sync` (başarıda kuyruğu temizle, retry politikası)
- [ ] Hata zarfı (`error_code`, `message`, `details`) için tek parser
- [ ] Canlı telemetri: `WS /ws/live` (auth mesajı, exponential backoff, heartbeat, `schema_mismatch`)
- [ ] `CORS_ORIGINS` varsayılanı `*`: production'da kısıtla

## P3: Çizim araçları

- [ ] Hat çizimi: çok noktalı polyline, tıkla-ekle / çift tıkla-bitir, her nokta parsel içinde
- [ ] Alan (poligon) varlıkları çizimi (`Polygon` tipi modelde var)
- [ ] Düğüm sürükleyerek hat/alan düzenleme
- [ ] Geri al / yinele
- [ ] Hat uzunluğu ve alan değerlerinin otomatik hesaplanması

## P4: Test ve kalite

- [~] GIS birim testleri (Vitest, 10 test) ve sözleşme testleri
- [ ] Yükleme mantığı için birim test (FeatureCollection, tek Feature, parselNo'suz, projeksiyonlu, bozuk dosya). Yükleme kodunu `App.tsx`'ten `gisService`'e taşıyıp test et
- [ ] Bileşen testleri (Testing Library): araç seç → parsel içine ekle → dışına eklemeyi reddet
- [ ] Backend API test kapsamı: kritik uçlar (fault, IoT yaşam döngüsü, sync) için başarılı/hata senaryoları (`pytest` bu çalışmada çalıştırılmadı)
- [ ] Web + backend uçtan uca smoke testi (telemetri → WS → arayüz rozeti)
- [ ] CI'a Vercel önizleme kontrolü

## Güvenlik ve altyapı

- [x] Git remote adresinden GitHub token'ı kaldırıldı
- [ ] Konuşmalarda paylaşılmış GitHub token'larını GitHub'da iptal et (Settings → Developer settings → Tokens); yenisini yalnızca credential helper/SSH ile kullan
- [ ] Release kontrol listesi (tek checklist)
