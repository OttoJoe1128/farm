from __future__ import annotations

import datetime
import uuid
from typing import Any, Dict, List


def now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sanitize_work_order(raw: Dict[str, Any]) -> Dict[str, Any]:
    item: Dict[str, Any] = dict(raw)
    work_order_id: str = str(item.get("work_order_id") or uuid.uuid4().hex)
    status: str = str(item.get("status") or "open")
    created_at: str = str(item.get("created_at") or now_iso())
    updated_at: str = str(item.get("updated_at") or created_at)
    return {
        **item,
        "work_order_id": work_order_id,
        "status": status,
        "created_at": created_at,
        "updated_at": updated_at,
    }


def append_work_order(storage: List[Dict[str, Any]], new_item: Dict[str, Any]) -> Dict[str, Any]:
    sanitized = sanitize_work_order(new_item)
    storage.append(sanitized)
    return sanitized


def update_work_order(storage: List[Dict[str, Any]], work_order_id: str, patch: Dict[str, Any]) -> Dict[str, Any]:
    target_id: str = str(work_order_id)
    for idx, existing in enumerate(storage):
        if str(existing.get("work_order_id", "")) != target_id:
            continue
        merged = {**existing, **patch}
        merged["work_order_id"] = target_id
        merged["updated_at"] = now_iso()
        storage[idx] = sanitize_work_order(merged)
        return storage[idx]
    raise ValueError("work_order_not_found")
