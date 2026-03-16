from __future__ import annotations

import datetime
import hashlib
import hmac
import os
import uuid
from typing import Any, Dict, List


def now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def normalize_telemetry(payload: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(payload)
    out["asset_id"] = str(out.get("asset_id", "")).strip()
    out["device_id"] = str(out.get("device_id", "")).strip()
    out["measured_at"] = str(out.get("measured_at") or now_iso())
    out["received_at"] = str(out.get("received_at") or now_iso())
    out["source"] = str(out.get("source") or "api")
    out["quality_flag"] = str(out.get("quality_flag") or "raw")
    out["ingested_at"] = now_iso()
    return out


def detect_alerts(payload: Dict[str, Any], thresholds: Dict[str, Any]) -> List[Dict[str, Any]]:
    alerts: List[Dict[str, Any]] = []
    numeric_keys = [
        ("soil_moisture_pct", "soil_moisture_min", "soil_moisture_max"),
        ("air_temperature_c", "air_temperature_min", "air_temperature_max"),
    ]
    for metric_key, min_key, max_key in numeric_keys:
        try:
            value = float(payload.get(metric_key))
        except Exception:
            continue
        min_raw = thresholds.get(min_key)
        max_raw = thresholds.get(max_key)
        try:
            min_value = float(min_raw) if min_raw not in (None, "") else None
        except Exception:
            min_value = None
        try:
            max_value = float(max_raw) if max_raw not in (None, "") else None
        except Exception:
            max_value = None
        if min_value is not None and value < min_value:
            alerts.append(
                {
                    "alert_id": uuid.uuid4().hex,
                    "metric": metric_key,
                    "severity": "warning",
                    "rule": "min",
                    "threshold": min_value,
                    "value": value,
                    "status": "open",
                    "ack_at": None,
                    "ack_by": None,
                    "close_at": None,
                    "close_by": None,
                    "close_reason": None,
                    "at": now_iso(),
                }
            )
        if max_value is not None and value > max_value:
            alerts.append(
                {
                    "alert_id": uuid.uuid4().hex,
                    "metric": metric_key,
                    "severity": "warning",
                    "rule": "max",
                    "threshold": max_value,
                    "value": value,
                    "status": "open",
                    "ack_at": None,
                    "ack_by": None,
                    "close_at": None,
                    "close_by": None,
                    "close_reason": None,
                    "at": now_iso(),
                }
            )
    return alerts


def create_device_registration(
    *,
    asset_id: str,
    requested_device_id: str = "",
    model: str = "",
    firmware_version: str = "",
) -> Dict[str, Any]:
    device_id = requested_device_id.strip() or uuid.uuid4().hex
    secret_seed = f"{device_id}:{asset_id}:{now_iso()}:{os.getenv('SECRET_KEY', 'smartfarm')}"
    api_key = hashlib.sha256(secret_seed.encode("utf-8")).hexdigest()
    topic_policy = {
        "telemetry_publish_topic": f"smartfarm/{asset_id}/{device_id}/telemetry",
        "command_subscribe_topic": f"smartfarm/{asset_id}/{device_id}/command",
    }
    return {
        "device_id": device_id,
        "asset_id": asset_id,
        "model": model,
        "firmware_version": firmware_version,
        "api_key": api_key,
        "topic_policy": topic_policy,
        "status": "active",
        "created_at": now_iso(),
        "updated_at": now_iso(),
    }


def rotate_device_key(device: Dict[str, Any]) -> Dict[str, Any]:
    device_id = str(device.get("device_id", ""))
    asset_id = str(device.get("asset_id", ""))
    rotated = dict(device)
    new_seed = f"{device_id}:{asset_id}:{now_iso()}:{uuid.uuid4().hex}"
    rotated["api_key"] = hmac.new(
        key=asset_id.encode("utf-8"),
        msg=new_seed.encode("utf-8"),
        digestmod=hashlib.sha256,
    ).hexdigest()
    rotated["updated_at"] = now_iso()
    return rotated


def apply_alert_ack(
    alerts: List[Dict[str, Any]],
    alert_id: str,
    operator: str,
) -> Dict[str, Any]:
    for idx, alert in enumerate(alerts):
        if str(alert.get("alert_id", "")) != str(alert_id):
            continue
        updated = dict(alert)
        updated["status"] = "acked" if str(updated.get("status", "open")) != "closed" else "closed"
        updated["ack_at"] = now_iso()
        updated["ack_by"] = operator
        alerts[idx] = updated
        return updated
    raise ValueError("alert_not_found")


def apply_alert_close(
    alerts: List[Dict[str, Any]],
    alert_id: str,
    operator: str,
    reason: str,
) -> Dict[str, Any]:
    for idx, alert in enumerate(alerts):
        if str(alert.get("alert_id", "")) != str(alert_id):
            continue
        updated = dict(alert)
        updated["status"] = "closed"
        updated["close_at"] = now_iso()
        updated["close_by"] = operator
        updated["close_reason"] = reason
        if updated.get("ack_at") is None:
            updated["ack_at"] = updated["close_at"]
            updated["ack_by"] = operator
        alerts[idx] = updated
        return updated
    raise ValueError("alert_not_found")
