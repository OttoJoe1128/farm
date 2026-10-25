# SmartFarm XR

Tarımsal parselleri kadastro sınırlarıyla uydu görüntüsü üzerinde gösteren, parsel içinde dijital ikiz varlıkları (ağaç, yapı, kuyu, sensör, GES, boru/kablo hatları) yöneten, IoT telemetrisini ve iş emirlerini izleyen **web tabanlı** çiftlik yönetim platformudur. Vercel üzerinde çalışır.

Yapılacaklar için: [`TODO.md`](./TODO.md)

## Mimari

| Katman | Teknoloji | Konum | Nerede çalışır |
|---|---|---|---|
| Web arayüzü | React 19, TypeScript, Vite, Tailwind 4, Leaflet | `src/` | **Vercel** (statik Vite çıktısı) |
| API | FastAPI (kimlik doğrulama, GIS, IoT, iş emirleri, WebSocket) | `backend/` | Vercel dışında (Docker / VM). Uzun ömürlü WebSocket gerektirdiği için |
| Depolama | JSON dosyası (varsayılan) veya PostgreSQL + PostGIS | `backend/services/storage.py` | Backend ile birlikte |

Şu an arayüz tek başına çalışır: veriler tarayıcıda `localStorage` içinde (`smartfarm_state_v2`) tutulur ve backend'e henüz bağlı değildir (bkz. `TODO.md`, P3).

## Temel özellikler

- **Harita ve parsel:** ESRI uydu / OpenStreetMap katmanları, GeoJSON (TKGM) parsel yükleme, parsel sınırı ve ızgara (0.5 m'den başlayan, parsele göre ölçeklenen) üzerine kenetlenme, mesafe ölçümü.
- **Parsel kuralı:** Varlıklar yalnızca tıklanan parselin sınırları içine eklenir, taşınır; dışı için uyarı verilir. Her varlık `parcel_id` ile ait olduğu parsele bağlanır.
- **Dijital ikiz varlıklar:** Yerel metre koordinatları (`local_x_m`, `local_y_m`), dijital kart (künye, sağlık, IoT, bakım, üretim, alarm eşikleri), denetim günlüğü.
- **İş emirleri:** Durum ve öncelik yönetimi, varlıktan tek tıkla iş emri oluşturma.
- **IoT:** Canlı telemetri (`ws.live.telemetry.v1`), eşik alarmları, alarm onaylama/kapatma.
- **Yönetim:** Rol tabanlı kullanıcılar (superadmin, admin, operator, viewer) ve arama destekli denetim günlüğü.

## Yerelde çalıştırma

```bash
npm install
npm run dev       # http://localhost:3000
npm test          # Vitest (GIS ve sözleşme testleri)
npm run build     # tsc + vite build -> dist/
```

### Backend

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
SECRET_KEY=degistir .venv/bin/uvicorn main:app --reload --port 8000
pytest            # repo kökünden
```

Swagger: `http://localhost:8000/docs`. Docker: `SECRET_KEY=... docker compose up` (PostGIS için `--profile postgis`).

Ortam değişkenleri: `SECRET_KEY` (production'da zorunlu), `ENVIRONMENT`, `CORS_ORIGINS`, `DEFAULT_ADMIN_EMAIL` / `DEFAULT_ADMIN_PASSWORD`, `DB_FILE`, `USERS_FILE`, `UPLOAD_DIR`, `MAX_UPLOAD_BYTES`, `STORAGE_BACKEND` (`json` | `postgis`), `DATABASE_URL`.

## Vercel dağıtımı

- Vercel projesinin **Root Directory** değeri bu deponun kökü olmalıdır.
- Framework: Vite. Build komutu `npm run build`, çıktı klasörü `dist`.
- Backend Vercel'e dağıtılmaz. Arayüzün backend'e bağlanması için API adresi bir ortam değişkeni (ör. `VITE_API_URL`) olarak eklenecek (bkz. `TODO.md`, P3).

## Backend API sözleşmesi (özet)

- Sürüm: `farm.v1.1.phase2`. Tüm yanıtlar `_meta` (`api_version`, `request_id`, `served_at`, `user_id`) içerir.
- Hata gövdesi: `{ ok: false, error_code, message, details, _meta }`.
- Keşif: `GET /api/v1/contracts`; OpenAPI: `/docs`, `/openapi.json`.
- GIS: `/api/v1/gis/*` (varlık ekle/güncelle/sil, `sync`, `assets/in-bbox`, arıza kayıtları ve çözümleme), `POST /api/v1/field/ingest`.
- Çakışma politikaları: `latest_timestamp_wins`, `incoming_wins`, `existing_wins`.
- Varlık kataloğu: `GET /api/v1/catalog/asset-types`, `POST /api/v1/catalog/validate`.
- IoT: `/api/v1/iot/*` (cihaz kaydı, telemetri, alarmlar). Canlı akış `WS /ws/live`: bağlandıktan sonra ilk mesaj `{"type":"auth","token":"<access_token>"}` olmalı (10 sn içinde); kullanıcıya yalnızca kendi olayları gönderilir.
- İş emirleri: `/api/v1/work-orders`. Analitik/ERP: `/api/v1/analytics/kpi`, `/api/v1/integrations/erp/*`.
