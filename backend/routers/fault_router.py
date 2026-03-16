from __future__ import annotations

from typing import Any, Callable, Dict, List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel


class FaultLogCreateRequest(BaseModel):
    asset_id: str
    description: str
    severity: Optional[str] = "medium"
    status: Optional[str] = "open"
    user_id: Optional[str] = None
    created_at: Optional[str] = None
    resolved_at: Optional[str] = None
    photo_url: Optional[str] = None


class FaultResolveRequest(BaseModel):
    resolved_at: Optional[str] = None
    note: Optional[str] = ""
    resolver_user_id: Optional[str] = None


def create_fault_router(
    *,
    get_current_user: Callable[..., Dict[str, Any]],
    get_user_state: Callable[[str], Dict[str, Any]],
    save_user_state: Callable[[str, Dict[str, Any]], None],
    touch_user_state: Callable[[Dict[str, Any]], None],
    find_asset_index_by_id: Callable[[List[Dict[str, Any]], str], int],
    ensure_asset_identity: Callable[[Dict[str, Any]], Dict[str, Any]],
    with_meta: Callable[[Dict[str, Any], Dict[str, Any] | None], Dict[str, Any]],
    api_error: Callable[..., Any],
    build_fault_log_entry: Callable[[Any, Dict[str, Any]], Dict[str, Any]],
) -> APIRouter:
    router = APIRouter()

    @router.post("/api/v1/gis/add-fault")
    def add_fault_record(
        request: FaultLogCreateRequest,
        current_user: Dict[str, Any] = Depends(get_current_user),
    ):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
        target_index: int = find_asset_index_by_id(map_data, request.asset_id)
        if target_index < 0:
            api_error(
                status_code=404,
                error_code="asset_not_found",
                message="Ariza kaydi eklenecek varlik bulunamadi.",
                details={"asset_id": request.asset_id},
            )
        fault_logs: List[Dict[str, Any]] = list(user_state.get("fault_logs", []))
        fault_log: Dict[str, Any] = build_fault_log_entry(request, current_user)
        fault_logs.append(fault_log)
        target_asset: Dict[str, Any] = ensure_asset_identity(map_data[target_index])
        properties: Dict[str, Any] = dict(target_asset.get("properties", {}))
        asset_logs: List[Dict[str, Any]] = list(properties.get("logs", []))
        asset_logs.append(
            {
                "id": fault_log["log_id"],
                "type": "fault",
                "description": fault_log["description"],
                "severity": fault_log["severity"],
                "status": fault_log["status"],
                "at": fault_log["created_at"],
            }
        )
        properties["logs"] = asset_logs[-200:]
        open_fault_count = 0
        for item in asset_logs:
            if str(item.get("status", "open")) != "resolved":
                open_fault_count += 1
        properties["open_fault_count"] = open_fault_count
        properties["last_fault_at"] = fault_log["created_at"]
        target_asset["properties"] = properties
        map_data[target_index] = ensure_asset_identity(target_asset)
        user_state["fault_logs"] = fault_logs[-5000:]
        user_state["map"] = map_data
        touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)
        return with_meta(
            {
                "status": "ok",
                "fault": fault_log,
                "asset_projection": {
                    "asset_id": request.asset_id,
                    "open_fault_count": open_fault_count,
                    "last_fault_at": fault_log["created_at"],
                },
            },
            current_user,
        )

    @router.get("/api/v1/gis/faults")
    def list_fault_logs(
        asset_id: Optional[str] = None,
        status: Optional[str] = None,
        current_user: Dict[str, Any] = Depends(get_current_user),
    ):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        fault_logs: List[Dict[str, Any]] = list(user_state.get("fault_logs", []))
        results: List[Dict[str, Any]] = []
        for item in fault_logs:
            if not isinstance(item, dict):
                continue
            if asset_id is not None and str(item.get("asset_id", "")) != str(asset_id):
                continue
            if status is not None and str(item.get("status", "")) != str(status):
                continue
            results.append(item)
        return with_meta(
            {"status": "ok", "count": len(results), "items": results[-1000:]},
            current_user,
        )

    @router.patch("/api/v1/gis/faults/{log_id}/resolve")
    def resolve_fault_log(
        log_id: str,
        request: FaultResolveRequest,
        current_user: Dict[str, Any] = Depends(get_current_user),
    ):
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        fault_logs: List[Dict[str, Any]] = list(user_state.get("fault_logs", []))
        map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
        target_index: int = -1
        for idx, item in enumerate(fault_logs):
            if str(item.get("log_id", "")) == str(log_id):
                target_index = idx
                break
        if target_index < 0:
            api_error(
                status_code=404,
                error_code="fault_not_found",
                message="Cozulecek ariza kaydi bulunamadi.",
                details={"log_id": log_id},
            )
        row: Dict[str, Any] = dict(fault_logs[target_index])
        if str(row.get("status", "open")) == "resolved":
            return with_meta(
                {
                    "status": "ok",
                    "fault": row,
                    "asset_projection": {
                        "asset_id": str(row.get("asset_id", "")),
                        "open_fault_count": None,
                        "last_fault_at": str(row.get("created_at", "")),
                    },
                    "contract": {"log_semantics": "asset_projection_plus_event_log.v1"},
                },
                current_user,
            )
        resolved_at = str(request.resolved_at or row.get("resolved_at") or "")
        if resolved_at == "":
            from services.canonical_service import iso_now_utc

            resolved_at = iso_now_utc()
        row["status"] = "resolved"
        row["resolved_at"] = resolved_at
        updates: List[Dict[str, Any]] = list(row.get("updates", []))
        updates.append(
            {
                "event_type": "fault_resolved",
                "at": resolved_at,
                "resolver_user_id": str(request.resolver_user_id or current_user.get("id", "")),
                "note": str(request.note or ""),
            }
        )
        row["updates"] = updates[-50:]
        fault_logs[target_index] = row
        asset_id = str(row.get("asset_id", ""))
        asset_index = find_asset_index_by_id(map_data, asset_id)
        open_fault_count: Optional[int] = None
        if 0 <= asset_index < len(map_data):
            target_asset: Dict[str, Any] = ensure_asset_identity(map_data[asset_index])
            props: Dict[str, Any] = dict(target_asset.get("properties", {}))
            asset_logs: List[Dict[str, Any]] = list(props.get("logs", []))
            for i, asset_log in enumerate(asset_logs):
                if str(asset_log.get("id", "")) == str(log_id):
                    patched = dict(asset_log)
                    patched["status"] = "resolved"
                    patched["resolved_at"] = resolved_at
                    asset_logs[i] = patched
                    break
            open_fault_count = 0
            for item in asset_logs:
                if str(item.get("status", "open")) != "resolved":
                    open_fault_count += 1
            props["logs"] = asset_logs[-200:]
            props["open_fault_count"] = open_fault_count
            target_asset["properties"] = props
            map_data[asset_index] = ensure_asset_identity(target_asset)
            user_state["map"] = map_data
        user_state["fault_logs"] = fault_logs[-5000:]
        touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)
        return with_meta(
            {
                "status": "ok",
                "fault": row,
                "asset_projection": {
                    "asset_id": asset_id,
                    "open_fault_count": open_fault_count,
                    "last_fault_at": str(row.get("created_at", "")),
                },
                "contract": {"log_semantics": "asset_projection_plus_event_log.v1"},
            },
            current_user,
        )

    return router
