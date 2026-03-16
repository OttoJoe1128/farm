# Saha Uygulamasi Faz 3 Gorev Raporu

Bu rapor, ana uygulama backend tarafindaki son durumla uyumlu saha uygulamasi islerini listeler.

## Durum Ozeti

- Ana uygulama backend:
  - Fault lifecycle: create/list/resolve tamam.
  - Response wrapper + `_meta` aktif.
  - Sync conflict policy servis tabanli.
  - Contract discovery endpoint aktif: `GET /api/v1/contracts`.
  - WebSocket telemetry schema freeze edildi: `ws.live.telemetry.v1`.
  - APIRouter ayrismasi tamam:
    - `routers/fault_router.py`
    - `routers/sync_router.py`
    - `routers/iot_router.py`
  - Endpoint pathlari degismedi (backward-compatible).
  - APIRouter ayrismasi tamam:
    - `routers/fault_router.py`
    - `routers/sync_router.py`
    - `routers/iot_router.py`
  - Endpoint pathlari degismedi (backward-compatible).

## Saha Uygulamasi Icin Yapilacaklar

## 1) Contract Discovery Bootstrap

- Uygulama acilisinda `GET /api/v1/contracts` cagrisi yap.
- Asagidaki degerleri runtime check et:
  - `contract_version`
  - `ws_live_schema.version`
  - `conflict_policies`
- Uyumsuzlukta fallback/uyari mekanizmasi calistir.

## 2) Sync ve Fault Semantigi

- Fault olusturma:
  - `POST /api/v1/gis/add-fault`
- Fault listeleme:
  - `GET /api/v1/gis/faults?asset_id=...&status=open`
- Fault cozumleme:
  - `PATCH /api/v1/gis/faults/{log_id}/resolve`
- Kartta gostergeler:
  - `open_fault_count`
  - `last_fault_at`

## 3) Faz 3 Cihaz Metadata + WS Hazirligi

- Device metadata zorunlu alanlari:
  - `device_id`
  - `asset_id`
  - `firmware_version`
  - `battery_pct` (varsa)
  - `signal_dbm` (varsa)
- Telemetry gonderim endpointi:
  - `POST /api/v1/iot/telemetry`
- Onboarding endpointleri:
  - `POST /api/v1/iot/devices/register`
  - `GET /api/v1/iot/devices`
  - `POST /api/v1/iot/devices/{device_id}/rotate-key`

## 4) Canli Projection + Reconnect + Alarm Badge

- WS endpoint: `ws://<host>/ws/live`
- Event schema: `ws.live.telemetry.v1`
- Zorunlu event alanlari:
  - `type=telemetry`, `asset_id`, `device_id`, `metrics`, `alerts`, `measured_at`
- Reconnect stratejisi:
  - exponential backoff: 1s, 2s, 4s, 8s, 16s (max 30s)
- Heartbeat:
  - ping timeout 45s
  - server timeout event: `heartbeat_timeout`
  - schema mismatch event: `schema_mismatch`
- Alarm badge:
  - `alerts.length` bazli artis
  - `asset_id` bazli detay karti badge update

## 5) E2E Test Matrisi (Ortak)

1. `POST /api/v1/iot/telemetry` -> 200 + `_meta`
2. Ayni anda `WS /ws/live` abonesi telemetry event alir
3. Event `schema_version == ws.live.telemetry.v1`
4. Saha UI:
   - ilgili varlik kartinda son olcum guncellenir
   - health badge/alarm badge artar
5. Fault acma + cozum:
   - `open_fault_count` beklendigi gibi azalir
6. Alarm lifecycle:
   - `PATCH /api/v1/iot/alerts/{alert_id}/ack`
   - `PATCH /api/v1/iot/alerts/{alert_id}/close`

## Faz 3 Icin Sonraki Isler (Saha Tarafi)

- Asset detail kartinda canli telemetry projection:
  - son olcum zamani (`measured_at`)
  - son metrik snapshot (`metrics`)
  - health/alarm badge (kural bazli renk/ikon)
- WS operasyonel dayaniklilik:
  - `heartbeat_timeout` olayinda reconnect queue reset
  - `schema_mismatch` olayinda contract refresh + kontrollu reconnect
- Onboarding UX:
  - cihaz kayit sonucu `topic_policy` alanlarini sakla
  - rotate-key akisini operator ekranina ekle
- Alarm lifecycle UI:
  - ack/close butonlari
  - `reason` ve `operator` alanlarini zorunlu/opsiyonel politika ile dogrula
- E2E otomasyon:
  - telemetry ingest -> ws event -> kart badge artisi
  - fault resolve -> `open_fault_count` azalisi

## Faz 3 Icin Sonraki Isler (Saha Tarafi)

- Asset detail kartinda canli telemetry projection:
  - son olcum zamani (`measured_at`)
  - son metrik snapshot (`metrics`)
  - health/alarm badge (kural bazli renk/ikon)
- WS operasyonel dayaniklilik:
  - `heartbeat_timeout` olayinda reconnect queue reset
  - `schema_mismatch` olayinda contract refresh + kontrollu reconnect
- Onboarding UX:
  - cihaz kayit sonucu `topic_policy` alanlarini sakla
  - rotate-key akisini operator ekranina ekle
- Alarm lifecycle UI:
  - ack/close butonlari
  - `reason` ve `operator` alanlarini zorunlu/opsiyonel politika ile dogrula
- E2E otomasyon:
  - telemetry ingest -> ws event -> kart badge artisi
  - fault resolve -> `open_fault_count` azalisi

## Not

- Iki repo ayriligini koru:
  - `farm` (ana backend + ana uygulama)
  - `smartfarm-field` (saha uygulamasi)
- Klasor birlestirme yok.

## Uygulama Durumu (Guncel)

- Contract discovery bootstrap saha tarafinda uygulandi.
- Sync/fault semantigi ve resolve akisi saha istemcisine eklendi.
- Faz 3 cihaz metadata hazirligi tamamlandi (`device_id`, server version, ws url cache).
- Canli projection + reconnect + alarm badge uygulandi.
