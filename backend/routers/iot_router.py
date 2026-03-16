from __future__ import annotations

import asyncio
from typing import Any, Callable, Dict, List

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from services.iot_service import (
    normalize_telemetry,
    detect_alerts,
    create_device_registration,
    rotate_device_key,
    apply_alert_ack,
    apply_alert_close,
)
from services.live_event_contract_service import (
    WS_EVENT_SCHEMA_VERSION,
    build_telemetry_event,
)


class TelemetryIngestRequest(BaseModel):
    asset_id: str
    device_id: str
    metrics: Dict[str, Any]
    measured_at: str | None = None
    quality_flag: str | None = "raw"
    source: str | None = "api"
    received_at: str | None = None


class DeviceRegisterRequest(BaseModel):
    asset_id: str
    device_id: str | None = ""
    model: str | None = ""
    firmware_version: str | None = ""


class AlertActionRequest(BaseModel):
    reason: str | None = ""
    operator: str | None = ""


def create_iot_router(
    *,
    get_current_user: Callable[..., Dict[str, Any]],
    get_user_state: Callable[[str], Dict[str, Any]],
    save_user_state: Callable[[str, Dict[str, Any]], None],
    touch_user_state: Callable[[Dict[str, Any]], None],
    find_asset_index_by_id: Callable[[List[Dict[str, Any]], str], int],
    ensure_asset_identity: Callable[[Dict[str, Any]], Dict[str, Any]],
    with_meta: Callable[[Dict[str, Any], Dict[str, Any] | None], Dict[str, Any]],
    api_error: Callable[..., Any],
    broadcast_live_event: Callable[[Dict[str, Any]], Any],
    iso_now_utc: Callable[[], str],
    live_websocket_clients: List[WebSocket],
    ws_heartbeat_timeout_seconds: int,
    ws_reconnect_hint: str,
) -> APIRouter:
    router = APIRouter()

    @router.post("/api/v1/iot/telemetry")
    async def ingest_telemetry(
        request: TelemetryIngestRequest,
        current_user: Dict[str, Any] = Depends(get_current_user),
    ):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
        telemetry_log: List[Dict[str, Any]] = list(user_state.get("telemetry_log", []))
        alerts: List[Dict[str, Any]] = list(user_state.get("alerts", []))
        normalized = normalize_telemetry(request.dict())
        if normalized.get("asset_id", "") == "":
            api_error(
                status_code=400,
                error_code="validation_error",
                message="asset_id zorunludur.",
                details={"field": "asset_id"},
            )
        target_index = find_asset_index_by_id(map_data, str(normalized["asset_id"]))
        if target_index < 0:
            api_error(
                status_code=404,
                error_code="asset_not_found",
                message="Telemetri gonderilecek varlik bulunamadi.",
                details={"asset_id": normalized.get("asset_id")},
            )
        target_asset = ensure_asset_identity(map_data[target_index])
        props: Dict[str, Any] = dict(target_asset.get("properties", {}))
        digital_card: Dict[str, Any] = dict(props.get("digital_card", {}))
        iot_card: Dict[str, Any] = dict(digital_card.get("iot", {}))
        alarm_card: Dict[str, Any] = dict(digital_card.get("alarm", {}))
        metrics: Dict[str, Any] = dict(normalized.get("metrics", {}))
        for key, value in metrics.items():
            iot_card[key] = value
        iot_card["last_seen_at"] = str(normalized.get("measured_at"))
        iot_card["updated_at"] = iso_now_utc()
        digital_card["iot"] = iot_card
        props["digital_card"] = digital_card
        detected_alerts = detect_alerts(iot_card, alarm_card)
        if len(detected_alerts) > 0:
            for alert in detected_alerts:
                alert["asset_id"] = normalized["asset_id"]
                alert["device_id"] = normalized["device_id"]
                alert["quality_flag"] = normalized.get("quality_flag")
                alert["source"] = normalized.get("source")
                alert["received_at"] = normalized.get("received_at")
                alert["ingested_at"] = normalized.get("ingested_at")
            alerts.extend(detected_alerts)
            alerts = alerts[-1000:]
        props["iot_connected"] = True
        target_asset["properties"] = props
        map_data[target_index] = ensure_asset_identity(target_asset)
        telemetry_log.append(normalized)
        telemetry_log = telemetry_log[-5000:]
        user_state["map"] = map_data
        user_state["telemetry_log"] = telemetry_log
        user_state["alerts"] = alerts
        touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)
        await broadcast_live_event(
            build_telemetry_event(
                asset_id=str(normalized["asset_id"]),
                device_id=str(normalized["device_id"]),
                metrics=metrics,
                alerts=detected_alerts,
                measured_at=str(normalized["measured_at"]),
            )
        )
        return with_meta(
            {"status": "ok", "telemetry": normalized, "alerts": detected_alerts},
            current_user,
        )

    @router.post("/api/v1/iot/devices/register")
    def register_iot_device(
        request: DeviceRegisterRequest,
        current_user: Dict[str, Any] = Depends(get_current_user),
    ):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
        target_index = find_asset_index_by_id(map_data, request.asset_id)
        if target_index < 0:
            api_error(
                status_code=404,
                error_code="asset_not_found",
                message="Cihaz kaydi icin varlik bulunamadi.",
                details={"asset_id": request.asset_id},
            )
        devices: List[Dict[str, Any]] = list(user_state.get("iot_devices", []))
        registration = create_device_registration(
            asset_id=str(request.asset_id),
            requested_device_id=str(request.device_id or ""),
            model=str(request.model or ""),
            firmware_version=str(request.firmware_version or ""),
        )
        devices = [
            row
            for row in devices
            if str(row.get("device_id", "")) != registration["device_id"]
        ]
        devices.append(registration)
        user_state["iot_devices"] = devices[-2000:]
        touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)
        return with_meta({"status": "ok", "device": registration}, current_user)

    @router.get("/api/v1/iot/devices")
    def list_iot_devices(current_user: Dict[str, Any] = Depends(get_current_user)):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        devices: List[Dict[str, Any]] = list(user_state.get("iot_devices", []))
        return with_meta(
            {"status": "ok", "items": devices, "count": len(devices)},
            current_user,
        )

    @router.post("/api/v1/iot/devices/{device_id}/rotate-key")
    def rotate_iot_device_key(
        device_id: str,
        current_user: Dict[str, Any] = Depends(get_current_user),
    ):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        devices: List[Dict[str, Any]] = list(user_state.get("iot_devices", []))
        found = -1
        for idx, row in enumerate(devices):
            if str(row.get("device_id", "")) == str(device_id):
                found = idx
                break
        if found < 0:
            api_error(
                status_code=404,
                error_code="device_not_found",
                message="Anahtar donusturulecek cihaz bulunamadi.",
                details={"device_id": device_id},
            )
        rotated = rotate_device_key(devices[found])
        devices[found] = rotated
        user_state["iot_devices"] = devices
        touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)
        return with_meta({"status": "ok", "device": rotated}, current_user)

    @router.get("/api/v1/iot/alerts")
    def list_alerts(current_user: Dict[str, Any] = Depends(get_current_user)):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        alerts: List[Dict[str, Any]] = list(user_state.get("alerts", []))
        return with_meta(
            {"status": "ok", "items": alerts, "count": len(alerts)},
            current_user,
        )

    @router.patch("/api/v1/iot/alerts/{alert_id}/ack")
    def ack_alert(
        alert_id: str,
        request: AlertActionRequest,
        current_user: Dict[str, Any] = Depends(get_current_user),
    ):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        alerts: List[Dict[str, Any]] = list(user_state.get("alerts", []))
        operator = str(request.operator or current_user.get("id", ""))
        try:
            updated = apply_alert_ack(alerts, alert_id, operator)
        except ValueError:
            api_error(
                status_code=404,
                error_code="alert_not_found",
                message="Onaylanacak alarm bulunamadi.",
                details={"alert_id": alert_id},
            )
        user_state["alerts"] = alerts
        touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)
        return with_meta({"status": "ok", "alert": updated}, current_user)

    @router.patch("/api/v1/iot/alerts/{alert_id}/close")
    def close_alert(
        alert_id: str,
        request: AlertActionRequest,
        current_user: Dict[str, Any] = Depends(get_current_user),
    ):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        alerts: List[Dict[str, Any]] = list(user_state.get("alerts", []))
        operator = str(request.operator or current_user.get("id", ""))
        reason = str(request.reason or "")
        try:
            updated = apply_alert_close(alerts, alert_id, operator, reason)
        except ValueError:
            api_error(
                status_code=404,
                error_code="alert_not_found",
                message="Kapatilacak alarm bulunamadi.",
                details={"alert_id": alert_id},
            )
        user_state["alerts"] = alerts
        touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)
        return with_meta({"status": "ok", "alert": updated}, current_user)

    @router.websocket("/ws/live")
    async def websocket_live(websocket: WebSocket):
        await websocket.accept()
        live_websocket_clients.append(websocket)
        try:
            await websocket.send_json(
                {
                    "type": "connected",
                    "at": iso_now_utc(),
                    "schema_version": WS_EVENT_SCHEMA_VERSION,
                }
            )
            while True:
                try:
                    incoming = await asyncio.wait_for(
                        websocket.receive_json(),
                        timeout=ws_heartbeat_timeout_seconds,
                    )
                    if isinstance(incoming, dict) and str(incoming.get("type")) == "ping":
                        incoming_schema = str(
                            incoming.get("schema_version", WS_EVENT_SCHEMA_VERSION)
                        )
                        if incoming_schema != WS_EVENT_SCHEMA_VERSION:
                            await websocket.send_json(
                                {
                                    "type": "schema_mismatch",
                                    "expected": WS_EVENT_SCHEMA_VERSION,
                                    "received": incoming_schema,
                                    "reconnect_hint": ws_reconnect_hint,
                                }
                            )
                            await websocket.close(code=4001)
                            break
                        await websocket.send_json(
                            {
                                "type": "pong",
                                "at": iso_now_utc(),
                                "schema_version": WS_EVENT_SCHEMA_VERSION,
                                "heartbeat_timeout_seconds": ws_heartbeat_timeout_seconds,
                                "reconnect_hint": ws_reconnect_hint,
                            }
                        )
                except asyncio.TimeoutError:
                    await websocket.send_json(
                        {
                            "type": "heartbeat_timeout",
                            "at": iso_now_utc(),
                            "schema_version": WS_EVENT_SCHEMA_VERSION,
                            "heartbeat_timeout_seconds": ws_heartbeat_timeout_seconds,
                            "reconnect_hint": ws_reconnect_hint,
                        }
                    )
                    await websocket.close(code=4000)
                    break
                except Exception:
                    await websocket.receive_text()
        except WebSocketDisconnect:
            pass
        finally:
            if websocket in live_websocket_clients:
                live_websocket_clients.remove(websocket)

    return router
