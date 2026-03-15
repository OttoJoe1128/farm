from __future__ import annotations

import datetime
from typing import Any, Dict


def utc_now_iso() -> str:
    return datetime.datetime.utcnow().isoformat()


def bump_state_version(user_state: Dict[str, Any]) -> Dict[str, Any]:
    next_version: int = int(user_state.get("version", 0)) + 1
    user_state["version"] = next_version
    user_state["updated_at"] = utc_now_iso()
    return user_state
