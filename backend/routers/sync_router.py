from __future__ import annotations

from typing import Any, Callable, Dict, List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel


class SyncOperation(BaseModel):
    client_op_id: str
    type: str
    payload: Dict[str, Any] = {}
    created_at: Optional[str] = None


class SyncRequest(BaseModel):
    base_version: Optional[int] = None
    ops: List[SyncOperation] = []
    sync_requested_at: Optional[str] = None
    conflict_policy: Optional[str] = "latest_timestamp_wins"


def create_sync_router(
    *,
    get_current_user: Callable[..., Dict[str, Any]],
    get_user_state: Callable[[str], Dict[str, Any]],
    save_user_state: Callable[[str, Dict[str, Any]], None],
    touch_user_state: Callable[[Dict[str, Any]], None],
    canonicalize_map_items: Callable[[List[Dict[str, Any]]], List[Dict[str, Any]]],
    ensure_asset_identity: Callable[[Dict[str, Any]], Dict[str, Any]],
    resolve_asset_conflict: Callable[[Dict[str, Any], Dict[str, Any], str], Dict[str, Any]],
    find_asset_index: Callable[[List[Dict[str, Any]], Dict[str, Any]], int],
    iso_now_utc: Callable[[], str],
    with_meta: Callable[[Dict[str, Any], Dict[str, Any] | None], Dict[str, Any]],
) -> APIRouter:
    router = APIRouter()

    @router.post("/api/v1/gis/sync")
    def sync_gis(
        request: SyncRequest,
        current_user: Dict[str, Any] = Depends(get_current_user),
    ):
        user_id: str = str(current_user["id"])
        user_state: Dict[str, Any] = get_user_state(user_id)
        server_version: int = int(user_state.get("version", 0))
        conflict_policy = str(request.conflict_policy or "latest_timestamp_wins")
        if (
            request.base_version is not None
            and request.base_version != server_version
            and len(request.ops) > 0
        ):
            return with_meta(
                {
                    "status": "conflict",
                    "reason": "version_mismatch",
                    "map": user_state.get("map", []),
                    "version": server_version,
                    "updated_at": user_state.get("updated_at"),
                    "policy_applied": conflict_policy,
                },
                current_user,
            )
        map_data: List[Dict[str, Any]] = canonicalize_map_items(list(user_state.get("map", [])))
        processed_ops: List[str] = list(user_state.get("processed_op_ids", []))
        processed_set = set(processed_ops)
        applied_count: int = 0
        skipped_count: int = 0
        conflicts: List[Dict[str, Any]] = []
        for op in request.ops:
            op_id: str = str(op.client_op_id).strip()
            if op_id == "" or op_id in processed_set:
                skipped_count += 1
                continue
            payload: Dict[str, Any] = dict(op.payload or {})
            op_type: str = str(op.type)
            if op_type == "add_asset":
                asset_obj: Any = payload.get("asset")
                if isinstance(asset_obj, dict):
                    map_data.append(ensure_asset_identity(asset_obj))
                    applied_count += 1
            elif op_type == "update_asset":
                asset_obj = payload.get("asset")
                target_index: int = find_asset_index(map_data, payload)
                if isinstance(asset_obj, dict) and 0 <= target_index < len(map_data):
                    existing_asset = ensure_asset_identity(map_data[target_index])
                    incoming_asset = ensure_asset_identity(asset_obj)
                    resolution = resolve_asset_conflict(
                        existing_asset=existing_asset,
                        incoming_asset=incoming_asset,
                        policy=conflict_policy,
                    )
                    map_data[target_index] = resolution["resolved_asset"]
                    applied_count += 1
                else:
                    conflicts.append(
                        {
                            "type": "update_asset_not_found",
                            "client_op_id": op_id,
                            "asset_id": payload.get("asset_id"),
                            "index": payload.get("index"),
                        }
                    )
            elif op_type == "delete_asset":
                target_index = find_asset_index(map_data, payload)
                if 0 <= target_index < len(map_data):
                    map_data.pop(target_index)
                    applied_count += 1
                else:
                    conflicts.append(
                        {
                            "type": "delete_asset_not_found",
                            "client_op_id": op_id,
                            "asset_id": payload.get("asset_id"),
                            "index": payload.get("index"),
                        }
                    )
            elif op_type == "upload_parcel":
                features: Any = payload.get("features", [])
                if isinstance(features, list) and len(features) > 0:
                    for feature in features:
                        if isinstance(feature, dict):
                            map_data.append(ensure_asset_identity(feature))
                    applied_count += 1
            elif op_type == "replace_snapshot":
                full_map: Any = payload.get("map")
                if isinstance(full_map, list):
                    map_data = canonicalize_map_items(
                        [item for item in full_map if isinstance(item, dict)]
                    )
                    applied_count += 1
            processed_set.add(op_id)
        if applied_count > 0:
            user_state["map"] = map_data
            touch_user_state(user_state)
        user_state["processed_op_ids"] = list(processed_set)[-500:]
        save_user_state(user_id, user_state)
        return with_meta(
            {
                "status": "ok",
                "applied": applied_count,
                "skipped": skipped_count,
                "map": canonicalize_map_items(user_state.get("map", [])),
                "version": user_state.get("version", 0),
                "updated_at": user_state.get("updated_at"),
                "conflicts": conflicts,
                "sync_requested_at": request.sync_requested_at or iso_now_utc(),
                "policy_applied": conflict_policy,
            },
            current_user,
        )

    return router
