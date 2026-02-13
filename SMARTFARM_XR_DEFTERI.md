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

### Flutter (donanim kisiti nedeniyle zorunlu)
```bash
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 --web-renderer html
```

### Backend
```bash
cd /home/ottojoe/farm/farm/backend
python3 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

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
- [ ] Kisa operasyon runbook'u (hata kodu -> aksiyon tablosu) ekleme

## 6) Kapanan / Silinen Gorevler
- Eski ayri roadmap ve tanitim dosyalari kaldirildi.
- Bu belge disinda proje tanitim/todo kaynagi tutulmayacak.

