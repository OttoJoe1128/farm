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
- [x] **Parsel kimliği çakışması:** `getParcelId`: `parcel_id` → `Ada/ParselNo` → geometri parmak izi. Yükleme sırasında her parsele `parcel_id` yazılıyor; `areSameParcel`, harita, üst çubuk ve yönetim paneli bu kimliği kullanıyor. "Parsel undefined" metinleri giderildi
- [x] **KML:** dosya seçiciden çıkarıldı; KML/XML yüklenirse net hata veriliyor. (KML desteği istenirse ayrı madde: `DOMParser` ile çevirici)
- [x] **Yükleme doğrulaması:** yapı (halka ≥ 4 nokta, sayısal koordinat), WGS84 aralığı ve projeksiyonlu (metre) koordinat tespiti; geçersiz kayıtlar uyarıyla atılıyor (`src/services/parcelImport.ts`)
- [x] **Yinelenen yükleme:** aynı kimlik + aynı geometri güncellenir, aynı kimlik + farklı geometri `-2` son ekiyle ayrı parsel olur
- [x] **`localStorage` kotası:** kayıt hatasında görünür uyarı; menüde "Verileri Yedekle (JSON)" ve aynı yükleme düğmesiyle yedekten geri yükleme (`src/services/persistence.ts`)
- [ ] Geri yükleme/yükleme alert/confirm yerine uygulama içi bildirim bileşeni (mevcut `showToast` deseni) kullansın
- [ ] KML desteği (isteniyorsa)
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

- [x] Neon projesi bağlandı (`neon.ts`: Postgres + `photos` bucket), `deploy` uygulandı; PostGIS depolamaya karşı backend testleri ve uçtan uca doğrulama geçti (kayıt, varlık + `parcel_id` kalıcılığı, yeniden başlatma sonrası veri, bbox sorgusu)
- [x] Fotoğraf yükleme Object Storage'a yazıyor (`backend/services/object_store.py`), imzalı adres + `GET /api/v1/gis/media/{id}/url`
- [ ] Backend'i Render'a (Docker) kur (`STORAGE_BACKEND=postgis`, `DATABASE_URL`=pooled olmayan adres, `AWS_*`); `SECRET_KEY`, `ENVIRONMENT=production`, `CORS_ORIGINS=<vercel domain>`, `DEFAULT_ADMIN_EMAIL/PASSWORD` ayarla
- [ ] Render'daki backend `/health` yanıtında `storage: postgis` gördüğünü doğrula
- [ ] Pooled (`DATABASE_URL`) ve pooled olmayan (`DATABASE_URL_UNPOOLED`) adres karşılaştırması: backend uzun ömürlü bağlantı tuttuğu için şimdilik pooled olmayan adresle test edildi
- [ ] Neon'daki `uploads` bucket'ı projede tanımlı değil (ben açmadım); kullanılmıyorsa sil, kullanılıyorsa `neon.ts`'e ekle
- [ ] `npm audit`: `vitest` zincirinde (`tinypool`, `@vitest/mocker`) 2 kritik/1 orta bulgu; yalnızca test aracı, `vitest` sürümünü güncelle
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

- [~] Vitest: GIS (10), sözleşme (4), parsel yükleme/kimlik/yedekleme (18) testleri
- [x] Yükleme mantığı için birim test (FeatureCollection, tek Feature, ParselNo'suz, projeksiyonlu, bozuk, tekrar yükleme, KML)
- [ ] Bileşen testleri (Testing Library): araç seç → parsel içine ekle → dışına eklemeyi reddet
- [ ] Backend API test kapsamı: kritik uçlar (fault, IoT yaşam döngüsü, sync) için başarılı/hata senaryoları (`pytest` bu çalışmada çalıştırılmadı)
- [ ] Web + backend uçtan uca smoke testi (telemetri → WS → arayüz rozeti)
- [ ] CI'a Vercel önizleme kontrolü

## Güvenlik ve altyapı

- [x] Git remote adresinden GitHub token'ı kaldırıldı
- [ ] Auth, Functions, AI Gateway, Realtime Neon servisleri bilerek açılmadı (kodda karşılığı yok); gerekince `neon.ts`'e eklenir
- [ ] Konuşmalarda paylaşılmış GitHub token'larını GitHub'da iptal et (Settings → Developer settings → Tokens); yenisini yalnızca credential helper/SSH ile kullan
- [ ] Release kontrol listesi (tek checklist)
