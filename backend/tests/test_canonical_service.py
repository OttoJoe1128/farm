from services.canonical_service import (
    canonicalize_map_items,
    ensure_asset_identity,
    find_asset_index_by_id,
    merge_by_latest_timestamp,
)


def _asset(name, updated_at, asset_id="a1"):
    return {
        "name": name,
        "geometry": {"type": "Point", "coordinates": [0, 0]},
        "properties": {"asset_id": asset_id, "timestamps": {"updated_at": updated_at}},
    }


def test_latest_timestamp_compares_instants_not_strings():
    existing = _asset("existing", "2026-01-01T10:00:00+03:00")
    incoming = _asset("incoming", "2026-01-01T08:00:00Z")
    assert merge_by_latest_timestamp(existing, incoming)["name"] == "incoming"


def test_latest_timestamp_treats_naive_as_utc():
    existing = _asset("existing", "2026-01-01T09:00:00")
    incoming = _asset("incoming", "2026-01-01T08:59:00+00:00")
    assert merge_by_latest_timestamp(existing, incoming)["name"] == "existing"


def test_ensure_asset_identity_preserves_existing_id_and_is_idempotent():
    first = ensure_asset_identity(_asset("x", "2026-01-01T00:00:00Z", asset_id="keep"))
    second = ensure_asset_identity(first)
    assert first["asset_id"] == second["asset_id"] == "keep"
    assert second["properties"]["meta"]["asset_id"] == "keep"


def test_category_inferred_from_icon():
    asset = ensure_asset_identity({"geometry": {"type": "Point"}, "style": {"icon": "water_drop"}})
    assert asset["properties"]["meta"]["category"] == "kuyu"
    assert asset["properties"]["meta"]["asset_type"] == "non_living"


def test_canonicalize_skips_non_dict_and_find_by_nested_id():
    items = canonicalize_map_items([_asset("x", "", asset_id="n1"), "junk", None])
    assert len(items) == 1
    assert find_asset_index_by_id(items, "n1") == 0
    assert find_asset_index_by_id(items, "  ") == -1
    assert find_asset_index_by_id([{"properties": {"meta": {"asset_id": "deep"}}}], "deep") == 0
