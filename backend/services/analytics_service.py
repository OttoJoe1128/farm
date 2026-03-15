from __future__ import annotations

from typing import Any, Dict, List


def build_kpi(
    map_items: List[Dict[str, Any]],
    work_orders: List[Dict[str, Any]],
    telemetry_log: List[Dict[str, Any]],
    alerts: List[Dict[str, Any]],
) -> Dict[str, Any]:
    parcel_count = 0
    asset_count = 0
    living_count = 0
    non_living_count = 0
    for item in map_items:
        geometry = item.get("geometry", {}) if isinstance(item, dict) else {}
        geometry_type = str((geometry or {}).get("type", ""))
        props = item.get("properties", {}) if isinstance(item, dict) else {}
        meta = props.get("meta", {}) if isinstance(props, dict) else {}
        if geometry_type in ("Polygon", "MultiPolygon") and str(meta.get("category", "")) == "parsel":
            parcel_count += 1
            continue
        asset_count += 1
        if str(meta.get("asset_type", "")) == "living":
            living_count += 1
        else:
            non_living_count += 1

    work_open = 0
    work_closed = 0
    for row in work_orders:
        status = str(row.get("status", "open"))
        if status in ("closed", "done", "completed"):
            work_closed += 1
        else:
            work_open += 1

    return {
        "assets_total": asset_count,
        "parcels_total": parcel_count,
        "living_assets": living_count,
        "non_living_assets": non_living_count,
        "work_orders_open": work_open,
        "work_orders_closed": work_closed,
        "telemetry_points": len(telemetry_log),
        "active_alerts": len(alerts),
    }
