# Smart Farm XR - Tek Proje Defteri

Bu dosya projedeki tek resmi tanitim + durum + TODO kaynagidir.

## 1) Proje Amaci
- Ciftlik parsellerini dijital ikiz olarak haritada yonetmek.
- Parsel ustune uydu goruntusunu birebir oturtup varlik yerlestirmeyi hizlandirmak.
- Dusuk donanimli Linux ortaminda stabil calismak.

## 2) Guncel Teknik Mimari

### Frontend
- Flutter + flutter_map
- Coklu parsel yukleme ve otomatik harita odaklama
- "Uyduyu Getir" aksiyonu (otomatik prefetch + elle yenileme)
- Uydu overlay'i backend'den gelen gercek bounds ile yerlestirme
- Snap, olcum modu ve nokta tabanli varlik gostergeleri

### Backend
- FastAPI (`backend/main.py`)
- Geometri hesaplari Web Mercator (EPSG:3857) tabanli
- Parsel maskeleme: OpenCV `fillPoly` ile dis alanlari tam seffaflama
- Uydu kaynagi fallback zinciri:
  - `esri`
  - `mapbox` (token/izin uygunsa)
  - `custom_xyz` (URL template ile)
- `custom_xyz` icin varsayilan ucretsiz deneme template'leri tanimli
- Esri export hatasinda XYZ tile fallback + stitch

## 3) Kritik Calistirma Notlari

### TEK PORT COZUMU (IDX / Cloud Workstations icin onerilen)
IDX ortaminda iki farkli port (8000/8080) CORS ve yetki sorunu yaratir.
Cozum: Flutter'i build edip backend uzerinden sun. Her sey tek portta calisir.

```bash
# 1. Flutter web build olustur
cd ~/farm/smartfarm_xr
flutter build web

# 2. Backend'i baslat (Flutter web dosyalarini da otomatik sunar)
cd ~/farm/backend
python3 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Sonra tarayicida tek adres:
```
https://8000-<IDX-id>.cluster-<cluster-id>.cloudworkstations.dev/
```
- `/` -> Flutter uygulamasi
- `/docs` -> FastAPI Swagger UI
- `/api/v1/...` -> API endpointleri

### Alternatif: Localhost gelistirme (IDX disinda)
```bash
# Terminal 1: Backend
cd backend && python3 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2: Flutter (debug modu)
cd smartfarm_xr && flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

### IDX Uygulama Acilis Sirasi (tek port)
1. `flutter build web` calistir (smartfarm_xr klasorunde).
2. Backend'i `8000` portunda baslat.
3. Tarayicida `https://8000-...cloudworkstations.dev/` ac. Hem uygulama hem API ayni adreste.
4. API testi icin: `https://8000-...cloudworkstations.dev/docs`

### Opsiyonel Env Ayarlari
- `MAPBOX_ACCESS_TOKEN`
- `IMAGERY_PROVIDER_MODE` (`auto|esri|mapbox|custom_xyz`)
- `IMAGERY_PROVIDER_PRIORITY` (ornek: `esri,mapbox,custom_xyz`)
- `CUSTOM_XYZ_TILE_TEMPLATE`
- `CUSTOM_XYZ_TILE_TEMPLATES` (virgulle birden cok template)
- `MIN_IMAGERY_YEAR` (varsayilan `2025`)
- `REQUIRE_KNOWN_FRESHNESS` (varsayilan `false`)

## 4) Guncel Durum (Tamamlananlar)
- [x] Coklu parsel yukleme
- [x] Parsel disi alanin tam seffaf maskelenmesi
- [x] Overlay'i gercek bounds ile oturtma
- [x] Uydu prefetch + onbellek + zorla yenile
- [x] Saglayici fallback (esri/mapbox/custom_xyz)
- [x] Esri export hata fallback (xyz tile stitch)
- [x] Snap ve olcum modu
- [x] Varlik ikonlarini nokta gorunumune indirme

## 5) Aktif TODO
- [ ] Canli ortamda tek bir lisansli ve guncel saglayiciyi netlestirip sabitleme
- [ ] `custom_xyz` kullanilacaksa hukuk/lisans uyumlulugunu dokumante etme
- [x] Kisa operasyon runbook'u (hata kodu -> aksiyon tablosu) eklendi

## 6) Kapanan / Silinen Gorevler
- Eski ayri roadmap ve tanitim dosyalari kaldirildi.
- Bu belge disinda proje tanitim/todo kaynagi tutulmayacak.

## 7) Sorun Giderme (Runbook)

### Hata Kodu -> Aksiyon
- `401` (`Mapbox Direct access not allowed`): token yetkisi yetersiz; `mapbox` devre disi kalir, `esri/custom_xyz` fallback kullanilir.
- `412` (`freshness` filtre): `MIN_IMAGERY_YEAR` ve `REQUIRE_KNOWN_FRESHNESS` ayarlarini kontrol et; gerekirse `REQUIRE_KNOWN_FRESHNESS=false`.
- `502` (`tile/export`): provider fallback logunu kontrol et; `custom_xyz` template'lerini guncelle veya `IMAGERY_PROVIDER_MODE=esri`.
- `422` (`upload-map`): frontend multipart gonderir; backend `UploadFile` endpointinin aktif oldugunu dogrula.

### Sik Senaryolar
- Uydu goruntusu gelmiyor: backend logunda `Uydu provider sirasi` ve `... hatasi` satirlarini kontrol et.
- Goruntu eski gorunuyor: `IMAGERY_PROVIDER_MODE=custom_xyz` ile alternatif template test et, uzun bas ile zorla yenile.
- Overlay kayik: `overlay_bounds` response alaninin geldigini ve frontend tarafinda kullanildigini dogrula.
- Web performans sorunu: Flutter'i sadece HTML renderer komutuyla calistir.

### Hazir Calistirma Profilleri
- Stabil profil (onerilen): `IMAGERY_PROVIDER_MODE=auto`
- Ucretsiz kaynak deneme: `IMAGERY_PROVIDER_MODE=custom_xyz`
- Sadece Esri: `IMAGERY_PROVIDER_MODE=esri`
- Sadece Mapbox (yetkili token varsa): `IMAGERY_PROVIDER_MODE=mapbox`

