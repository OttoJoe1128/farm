from __future__ import annotations

from typing import Any, Dict

try:
    from services.canonical_service import ensure_asset_identity, merge_by_latest_timestamp
except ModuleNotFoundError:
    from backend.services.canonical_service import (
        ensure_asset_identity,
        merge_by_latest_timestamp,
    )


SUPPORTED_CONFLICT_POLICIES = {
    "latest_timestamp_wins",
    "incoming_wins",
    "existing_wins",
}


def resolve_asset_conflict(
    existing_asset: Dict[str, Any],
    incoming_asset: Dict[str, Any],
    policy: str = "latest_timestamp_wins",
) -> Dict[str, Any]:
    normalized_policy: str = str(policy or "latest_timestamp_wins").strip()
    if normalized_policy not in SUPPORTED_CONFLICT_POLICIES:
        normalized_policy = "latest_timestamp_wins"
    left = ensure_asset_identity(existing_asset)
    right = ensure_asset_identity(incoming_asset)
    if normalized_policy == "incoming_wins":
        resolved = right
        decision = "incoming_wins"
    elif normalized_policy == "existing_wins":
        resolved = left
        decision = "existing_wins"
    else:
        resolved = merge_by_latest_timestamp(left, right)
        decision = "latest_timestamp_wins"
    return {
        "resolved_asset": resolved,
        "policy_applied": normalized_policy,
        "decision": decision,
    }
