# SmartFarm Ortak Yol Haritasi ve Operasyon Defteri

Bu dosya `farm` (ana uygulama) ve `smartfarm-field` (saha uygulamasi) ekiplerinin ortak yol haritasi kaynagidir.
Iki ekip de bu dosyayi guncelleyebilir.

## 1) Kapsam ve Amac
- Ana hedef: saha uygulamasi ile ana backend kontrat uyumunu koruyarak kararlı urun cikarmak.
- Bu dosya tek noktadan su ihtiyaclari yonetir:
  - Gelistirme asamalari
  - Ortak TODO listesi
  - Takvim ve sorumluluk dagilimi
  - Durum guncelleme kurallari

## 2) Mimari Cerceve (Kisa)

### Ana Uygulama (`farm`)
- Backend: FastAPI (`backend/main.py` + `backend/routers/*`)
- Yonetim paneli: `smartfarm_xr` (Flutter Web)
- Faz 3 kontratlari:
  - `GET /api/v1/contracts`
  - `WS /ws/live` (`ws.live.telemetry.v1`)
  - Fault lifecycle + IoT lifecycle endpointleri

### Saha Uygulamasi (`smartfarm-field`)
- Android Flutter istemcisi
- Ana backend'e veri gonderir (telemetry, fault, senkronizasyon)
- Faz 3 odaklari:
  - kontrat kesfi
  - canli projection
  - reconnect + heartbeat
  - alarm lifecycle

## 3) Guncel Durum Ozeti (2026-03-16)

### Tamamlananlar
- [x] Backend APIRouter moduler ayrisma tamam.
- [x] Faz 2/Faz 3 kontratlari dokumante ve endpoint pathleri backward-compatible.
- [x] Saha tarafi Faz 3 ana akislarinin commit zinciri tamamlandi (dis repoda).

### Aktif Riskler
- [ ] `farm` backend API test kapsami tum kritik endpointleri kapsamiyor.
- [ ] `smartfarm_xr` test kapsami iskelet seviyede.
- [ ] Saha + ana uygulama ortak E2E smoke otomasyonu eksik.
- [ ] Saha-Backend kontratinda fault resolve endpoint uyumsuzlugu riski var.
- [ ] Saha local `asset.id` ile backend `asset_id` esleme kurali net degil.
- [ ] `ws/live` akisinda auth/izolasyon sertlestirmesi ana uygulama tarafinda netlestirilmeli.

## 4) Ortak TODO Listesi (Tek Backlog)

| ID | Oncelik | Birim | Gorev | Durum | Bagimlilik | Cikis Kriteri |
|----|---------|-------|-------|-------|------------|---------------|
| ORTAK-009 | P0 | Ortak | Saha-Backend fault resolve kontratini tek endpointte dondur (`PATCH /api/v1/gis/faults/{log_id}/resolve`) | Acik | ORTAK-001 | Saha istemcisi ve backend ayni endpoint/method ile resolve akisinda yesil |
| ORTAK-010 | P0 | Ortak | `asset.id` (saha) -> `asset_id` (backend) esleme stratejisini sabitle ve dokumante et | Acik | ORTAK-001 | Device register, telemetry, fault akislari mapping ile 404 uretmeden calisiyor |
| ORTAK-011 | P0 | Ana Uygulama | `ws/live` auth + scope izolasyon sertlestirmesi | Acik | ORTAK-002 | Yetkisiz baglanti reddediliyor, canli event yalniz ilgili scope'a yayinlaniyor |
| ORTAK-012 | P0 | Saha Uygulamasi | API response parserlarini backend wrapper shape ile hizala (`data/items/detail`) | Acik | ORTAK-009 | `map/parcels/fault/alert` parse akislarinda runtime cast hatasi yok |
| ORTAK-013 | P0 | Saha Uygulamasi | Guvenlik sertlestirme: token saklama + cleartext baglanti kontrolu | Acik | ORTAK-012 | Hassas token guvenli depoda, production baglanti HTTPS kuraliyla calisiyor |
| ORTAK-014 | P1 | Ana Uygulama | Router seviyesinde hata envelope standardizasyonu (`error_code/message/detail`) | Acik | ORTAK-002 | Tum kritik hata senaryolari tek sekil parser ile saha tarafinda okunuyor |
| ORTAK-015 | P1 | Saha Uygulamasi | Sync queue semantigini tamamla (basarili durumda kuyruk temizleme + retry netligi) | Acik | ORTAK-010 | Kuyruk sismesi olmadan retry politikasi izlenebilir ve testli |
| ORTAK-001 | P0 | Ana Uygulama | Contract discovery snapshot testlerini genislet | Tamam | Yok | `contracts` endpoint shape + kritik endpoint listesi testte dogrulaniyor |
| ORTAK-002 | P0 | Ana Uygulama | Fault + IoT lifecycle API test kapsamini arttir | Devam Ediyor | ORTAK-001 | Kritik endpointler icin basarili/hata senaryolari otomatik calisiyor |
| ORTAK-003 | P0 | Saha Uygulamasi | Canli telemetry projection widget testleri | Acik | ORTAK-001 | Varlik listesi ve alarm badge yansimasi testten geciyor |
| ORTAK-004 | P0 | Saha Uygulamasi | Reconnect + heartbeat hata senaryolari | Acik | ORTAK-001 | `heartbeat_timeout` ve reconnect akislarinin testleri var |
| ORTAK-005 | P1 | Ana Uygulama | `backend/main.py` endpointlerini alan bazli routerlara tasima (path degismeden) | Acik | ORTAK-002 | Endpoint davranisi degismeden kod parcali ve testlenebilir |
| ORTAK-006 | P1 | Ana Uygulama | `smartfarm_xr` kritik widget testleri | Acik | ORTAK-002 | Auth/dashboard/canli gorunum testleri yesil |
| ORTAK-007 | P1 | Ortak | Saha + backend E2E smoke paketi | Acik | ORTAK-002, ORTAK-004 | Telemetry->WS->UI ve fault resolve akisi otomatik dogrulaniyor |
| ORTAK-008 | P2 | Ortak | Runbook ve release checklist birlestirme | Acik | ORTAK-007 | Tek checklist ile release oncesi kontrol tamamlaniyor |

## 5) Faz Bazli Yol Haritasi

### Faz A - Stabilizasyon (Mevcut Faz)
- Hedef: kontrat driftini durdurmak ve test guvenini yukselmek.
- Odak:
  - ORTAK-009, ORTAK-010, ORTAK-011, ORTAK-012, ORTAK-001, ORTAK-002, ORTAK-003, ORTAK-004

### Faz B - Sertlestirme
- Hedef: bakim maliyetini dusurmek ve CI kararliligini arttirmak.
- Odak:
  - ORTAK-013, ORTAK-014, ORTAK-015, ORTAK-005, ORTAK-006

### Faz C - Operasyonel Hazirlik
- Hedef: iki ekip icin ortak release mekanizmasi.
- Odak:
  - ORTAK-007, ORTAK-008

## 6) Bu Haftanin Uygulama Plani

### Ana Uygulama (`farm`)
1. ORTAK-009: Fault resolve endpoint kontratini saha ile netlestir ve sabitle.
2. ORTAK-011: `ws/live` auth + scope izolasyon sertlestirmesini ac.
3. ORTAK-001 ve ORTAK-002: Kontrat + lifecycle API test kapsamlarini tamamla.
4. ORTAK-014: Hata envelope standardini saha parserlarina uygun hale getir.

### Saha Uygulamasi (`smartfarm-field`)
1. ORTAK-010: `asset.id` -> `asset_id` mapping stratejisini kod ve depolamada sabitle.
2. ORTAK-012: API response parserlarini backend wrapper yapisiyla hizala.
3. ORTAK-003 ve ORTAK-004: Canli projection + reconnect/heartbeat test kapsamlarini genislet.
4. ORTAK-013: Token/transport guvenlik sertlestirmesi icin hazirlik dalini ac.
5. ORTAK-007 icin ortak smoke senaryolarina girdi sagla.

## 7) Guncelleme Kurali (Iki Ekip Icin)
- Her gorev guncellemesinde `Durum` alani degistirilir (`Acik`, `Devam Ediyor`, `Tamam`).
- Tamamlanan satira kisa not eklenir (commit hash veya tarih).
- Yeni is acilacaksa mevcut ID sirasina eklenir (orn: `ORTAK-009`).
- Bu dosya disinda ayri roadmap tutulmaz; eski dosyalar referans olarak kalabilir.
- Her yeni gelistirme adimindan once bu dosya okunur, once P0 acik maddelerden bir sonraki is secilir.
- Bir is `Tamam` olmadan bagimli sonraki asamaya gecilmez.
- Ana uygulama ajanina acik not: `farm` tarafinda calismaya baslamadan once bu dosyayi referans alip sadece buradaki aktif TODO satirlarina gore ilerle.

## 8) Referans Dosyalar
- `backend/ENDPOINT_CONTRACTS_PHASE2.md`
- `SAHA_UYGULAMASI_PHASE3_GOREV_RAPORU.md`
- `AYRI_REPO_SAHA.md`
- `IKI_UYGULAMA_OZETI.md`
- `PROSEDUR_TEST_APK.md`

