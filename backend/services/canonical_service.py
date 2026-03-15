from __future__ import annotations

import copy
import datetime
import uuid
from typing import Any, Dict, List, Optional


def iso_now_utc() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _to_dict(raw: Any) -> Dict[str, Any]:
    if isinstance(raw, dict):
        return dict(raw)
    return {}


def _to_list(raw: Any) -> List[Any]:
    if isinstance(raw, list):
        return list(raw)
    return []


def ensure_asset_identity(asset: Dict[str, Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = copy.deepcopy(asset)
    geometry: Dict[str, Any] = _to_dict(out.get("geometry"))
    properties: Dict[str, Any] = _to_dict(out.get("properties"))
    meta: Dict[str, Any] = _to_dict(properties.get("meta"))

    geometry_type: str = str(geometry.get("type", "")).strip() or str(out.get("type", "")).strip()
    icon_hint: str = str(_to_dict(out.get("style")).get("icon", "")).strip().lower()
    asset_id: str = str(
        out.get("asset_id")
        or properties.get("asset_id")
        or meta.get("asset_id")
        or uuid.uuid4().hex
    )

    is_point: bool = geometry_type == "Point"
    if icon_hint in ("agac", "park", "detected_tree"):
        category: str = "agac"
    elif icon_hint in ("kuyu", "water_drop"):
        category = "kuyu"
    elif icon_hint in ("sensor", "sensors"):
        category = "sensor"
    elif icon_hint in ("yapi", "home", "detected_building_shape"):
        category = "yapi"
    elif icon_hint in ("altyapi", "timeline", "bolt"):
        category = "altyapi"
    elif icon_hint in ("tarla", "landscape"):
        category = "tarla"
    else:
        category = str(meta.get("category", "")).strip() or ("agac" if is_point else "parsel")

    is_living_category = category in {"agac", "bitki"}
    asset_type: str = str(meta.get("asset_type", "")).strip() or ("living" if is_living_category else "non_living")

    timestamps: Dict[str, Any] = _to_dict(properties.get("timestamps"))
    now_iso: str = iso_now_utc()
    created_at: str = str(timestamps.get("created_at", "")).strip() or now_iso
    updated_at: str = str(timestamps.get("updated_at", "")).strip() or created_at
    timestamps = {
        **timestamps,
        "created_at": created_at,
        "updated_at": updated_at,
        "last_operation": str(timestamps.get("last_operation", "normalized") or "normalized"),
    }

    audit_log: List[Any] = _to_list(properties.get("audit_log"))
    if len(audit_log) == 0:
        audit_log.append({"at": created_at, "event": "asset_normalized"})

    meta = {
        **meta,
        "asset_id": asset_id,
        "asset_type": asset_type,
        "category": category,
        "geometry_type": geometry_type,
        "status": str(meta.get("status", "active")),
        "version": int(meta.get("version", 1) or 1),
    }

    properties = {
        **properties,
        "asset_id": asset_id,
        "meta": meta,
        "timestamps": timestamps,
        "audit_log": audit_log,
    }

    out["asset_id"] = asset_id
    out["properties"] = properties
    return out


def canonicalize_map_items(items: List[Any]) -> List[Dict[str, Any]]:
    result: List[Dict[str, Any]] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        result.append(ensure_asset_identity(item))
    return result


def find_asset_index_by_id(items: List[Dict[str, Any]], asset_id: str) -> int:
    lookup: str = str(asset_id).strip()
    if lookup == "":
        return -1
    for index, item in enumerate(items):
        item_id: str = str(
            item.get("asset_id")
            or _to_dict(item.get("properties")).get("asset_id")
            or _to_dict(_to_dict(item.get("properties")).get("meta")).get("asset_id")
            or ""
        ).strip()
        if item_id == lookup:
            return index
    return -1


def merge_by_latest_timestamp(existing: Dict[str, Any], incoming: Dict[str, Any]) -> Dict[str, Any]:
    left = ensure_asset_identity(existing)
    right = ensure_asset_identity(incoming)
    left_ts = str(_to_dict(_to_dict(left.get("properties")).get("timestamps")).get("updated_at", ""))
    right_ts = str(_to_dict(_to_dict(right.get("properties")).get("timestamps")).get("updated_at", ""))
    if right_ts >= left_ts:
        merged = right
        selected_event = "merged_incoming_latest"
    else:
        merged = left
        selected_event = "merged_existing_latest"
    merged_props = _to_dict(merged.get("properties"))
    merged_audit = _to_list(merged_props.get("audit_log"))
    merged_audit.append({"at": iso_now_utc(), "event": selected_event})
    merged_props["audit_log"] = merged_audit[-200:]
    merged["properties"] = merged_props
    return merged
