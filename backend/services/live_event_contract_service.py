from __future__ import annotations

from typing import Any, Dict, List


WS_EVENT_SCHEMA_VERSION = "ws.live.telemetry.v1"


def build_telemetry_event(
    *,
    asset_id: str,
    device_id: str,
    metrics: Dict[str, Any],
    alerts: List[Dict[str, Any]],
    measured_at: str,
) -> Dict[str, Any]:
    # Freeze edilen websocket kontrati: saha uygulamasi bu alanlara guvenir.
    return {
        "schema_version": WS_EVENT_SCHEMA_VERSION,
        "type": "telemetry",
        "asset_id": str(asset_id),
        "device_id": str(device_id),
        "metrics": dict(metrics),
        "alerts": list(alerts),
        "measured_at": str(measured_at),
    }
