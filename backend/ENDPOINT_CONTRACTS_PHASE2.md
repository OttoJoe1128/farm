# SmartFarm Backend Phase 2 Endpoint Contracts

This document fixes the contract between the main application backend and field clients.

## Contract Version

- `api_version`: `farm.v1.1.phase2`
- All Phase 2 responses include `_meta`:
  - `api_version`
  - `request_id`
  - `served_at`
  - `user_id`

## Standard Error Payload

HTTP errors can return:

```json
{
  "ok": false,
  "error_code": "asset_not_found",
  "message": "Human readable message",
  "details": {},
  "_meta": {
    "api_version": "farm.v1.1.phase2",
    "request_id": "..."
  }
}
```

## Discovery

- `GET /api/v1/contracts`
  - Returns contract version, endpoint list, expected response schema, and common error codes.
- OpenAPI:
  - Swagger UI: `/docs`
  - OpenAPI JSON: `/openapi.json`

## Router Modularization (Phase 2 Closure)

- Endpoint implementation has been moved to dedicated routers:
  - `backend/routers/fault_router.py`
  - `backend/routers/sync_router.py`
  - `backend/routers/iot_router.py`
- Contract paths are unchanged to preserve field compatibility.
- Target behavior:
  - stable response wrapper (`_meta`)
  - stable error envelope (`error_code`, `message`, `details`)
  - frozen WS telemetry schema (`ws.live.telemetry.v1`)

## Field Ingest

- `POST /api/v1/field/ingest`
  - Request:
    - `features`: feature list
    - `gps_points`: `{name, lat, lng, accuracy_m, captured_at, operator}`
    - `tkgm_context`: source context
  - Response:
    - `status`
    - `ingested`
    - `map`
    - `version`
    - `updated_at`
    - `_meta`

## Fault Logs (Asset/Log Semantics)

- `POST /api/v1/gis/add-fault`
  - Creates a canonical fault log (`fault_log.v1`) and projects summary into asset properties:
    - `properties.logs[]`
    - `properties.open_fault_count`
    - `properties.last_fault_at`

- `GET /api/v1/gis/faults?asset_id=&status=`
  - Lists fault logs with filtering.

- `PATCH /api/v1/gis/faults/{log_id}/resolve`
  - Resolves a fault log and updates related asset projection and log status.
  - Response includes:
    - `fault`
    - `asset_projection` (`asset_id`, `open_fault_count`, `last_fault_at`)
    - `contract.log_semantics = asset_projection_plus_event_log.v1`

## Conflict Policy

- Supported policies:
  - `latest_timestamp_wins`
  - `incoming_wins`
  - `existing_wins`
- Used by:
  - `POST /api/v1/gis/sync` (`conflict_policy`)
  - `POST /api/v1/gis/update-asset-by-id` (`conflict_policy` or legacy `merge_policy`)

## Work Orders

- `GET /api/v1/work-orders`
- `POST /api/v1/work-orders`
- `PATCH /api/v1/work-orders/{work_order_id}`

All responses include `_meta`.

## IoT

- `POST /api/v1/iot/devices/register`
  - Cihaz kaydi, anahtar uretimi ve topic policy doner.
- `GET /api/v1/iot/devices`
- `POST /api/v1/iot/devices/{device_id}/rotate-key`
- `POST /api/v1/iot/telemetry`
  - Writes telemetry, updates digital card iot section, evaluates alarms, emits live websocket event.
  - Telemetry quality fields:
    - `quality_flag`
    - `source`
    - `received_at`
    - `ingested_at`
- `GET /api/v1/iot/alerts`
- `PATCH /api/v1/iot/alerts/{alert_id}/ack`
  - Fields: `operator`
- `PATCH /api/v1/iot/alerts/{alert_id}/close`
  - Fields: `reason`, `operator`

All responses include `_meta`.

### WebSocket Live Event Schema (Frozen)

- Endpoint: `WS /ws/live`
- Telemetry event schema (frozen): `ws.live.telemetry.v1`
- Required fields:
  - `schema_version`
  - `type` (`telemetry`)
  - `asset_id`
  - `device_id`
  - `metrics`
  - `alerts`
  - `measured_at`
- Connection events:
  - `connected` (`schema_version`, `at`)
  - `pong` (`schema_version`, `at`)
- Operational behavior:
  - Ping timeout: `45s`
  - Server timeout event: `heartbeat_timeout`
  - Schema enforcement: ping paketindeki `schema_version` uyumsuzsa `schema_mismatch` donup baglanti kapatilir
  - Reconnect hint: `reconnect_with_exponential_backoff`

## Analytics / Integrations

- `GET /api/v1/analytics/kpi`
- `POST /api/v1/integrations/erp/sync`
- `GET /api/v1/integrations/erp/jobs`

All responses include `_meta`.

## E2E Contract Test Paketi

- Test file: `backend/tests/test_iot_lifecycle_contract.py`
- Kapsam:
  - telemetry normalize quality alanlari
  - device onboarding contract shape
  - alarm ack/close lifecycle
  - telemetry -> ws event contract shape
