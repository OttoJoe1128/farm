from __future__ import annotations

import datetime
from typing import Any, Dict


def now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def run_connector_sync(connector: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    connector_name = str(connector or "generic").strip().lower()
    return {
        "status": "queued",
        "connector": connector_name,
        "started_at": now_iso(),
        "summary": {
            "assets": len(payload.get("assets", [])) if isinstance(payload.get("assets"), list) else 0,
            "work_orders": len(payload.get("work_orders", []))
            if isinstance(payload.get("work_orders"), list)
            else 0,
        },
        "note": "POC connector run completed with dry-run semantics.",
    }
