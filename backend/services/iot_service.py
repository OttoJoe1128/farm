from __future__ import annotations

import datetime
from typing import Any, Dict, List


def now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def normalize_telemetry(payload: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(payload)
    out["asset_id"] = str(out.get("asset_id", "")).strip()
    out["device_id"] = str(out.get("device_id", "")).strip()
    out["measured_at"] = str(out.get("measured_at") or now_iso())
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
                    "metric": metric_key,
                    "severity": "warning",
                    "rule": "min",
                    "threshold": min_value,
                    "value": value,
                    "at": now_iso(),
                }
            )
        if max_value is not None and value > max_value:
            alerts.append(
                {
                    "metric": metric_key,
                    "severity": "warning",
                    "rule": "max",
                    "threshold": max_value,
                    "value": value,
                    "at": now_iso(),
                }
            )
    return alerts
