from conftest import make_point_asset


def _sync(client, headers, ops, **extra):
    response = client.post("/api/v1/gis/sync", headers=headers, json={"ops": ops, **extra})
    assert response.status_code == 200, response.text
    return response.json()


def _add_op(op_id, asset_id):
    return {"client_op_id": op_id, "type": "add_asset", "payload": {"asset": make_point_asset(asset_id=asset_id)}}


def test_add_asset_op_applied_once(client, headers):
    first = _sync(client, headers, [_add_op("op-1", "a1")])
    assert first["applied"] == 1
    replay = _sync(client, headers, [_add_op("op-1", "a1")])
    assert replay["applied"] == 0 and replay["skipped"] == 1
    assert [a["asset_id"] for a in replay["map"]] == ["a1"]


def test_version_mismatch_returns_conflict(client, headers):
    _sync(client, headers, [_add_op("op-1", "a1")])
    result = _sync(client, headers, [_add_op("op-2", "a2")], base_version=0)
    assert result["status"] == "conflict"
    assert result["reason"] == "version_mismatch"


def test_processed_op_ids_keep_most_recent_in_order(client, headers):
    ops = [{"client_op_id": f"op-{i}", "type": "delete_asset", "payload": {"asset_id": "none"}} for i in range(600)]
    _sync(client, headers, ops)
    import main as app_module

    state = app_module.load_db()["users"]
    processed = next(iter(state.values()))["processed_op_ids"]
    assert processed == [f"op-{i}" for i in range(100, 600)]
    replay = _sync(client, headers, ops[100:])
    assert replay["skipped"] == 500


def test_unsupported_op_type_is_reported(client, headers):
    result = _sync(client, headers, [{"client_op_id": "op-x", "type": "explode", "payload": {}}])
    assert result["applied"] == 0
    assert result["conflicts"] == [{"type": "unsupported_op_type", "client_op_id": "op-x", "op_type": "explode"}]


def test_update_and_delete_missing_assets_are_conflicts(client, headers):
    result = _sync(
        client,
        headers,
        [
            {"client_op_id": "u", "type": "update_asset", "payload": {"asset_id": "nope", "asset": make_point_asset()}},
            {"client_op_id": "d", "type": "delete_asset", "payload": {"asset_id": "nope"}},
        ],
    )
    assert [c["type"] for c in result["conflicts"]] == ["update_asset_not_found", "delete_asset_not_found"]


def test_update_asset_latest_timestamp_wins(client, headers):
    _sync(client, headers, [_add_op("op-1", "a1")])
    newer = make_point_asset(name="Yeni", asset_id="a1")
    newer["properties"]["timestamps"] = {"updated_at": "2999-01-01T00:00:00+00:00"}
    older = make_point_asset(name="Eski", asset_id="a1")
    older["properties"]["timestamps"] = {"updated_at": "2000-01-01T00:00:00+00:00"}
    _sync(client, headers, [{"client_op_id": "u1", "type": "update_asset", "payload": {"asset_id": "a1", "asset": newer}}])
    result = _sync(client, headers, [{"client_op_id": "u2", "type": "update_asset", "payload": {"asset_id": "a1", "asset": older}}])
    assert result["map"][0]["name"] == "Yeni"


def test_replace_snapshot_and_upload_parcel(client, headers):
    result = _sync(
        client,
        headers,
        [
            {"client_op_id": "r", "type": "replace_snapshot", "payload": {"map": [make_point_asset(asset_id="x"), "junk"]}},
            {"client_op_id": "p", "type": "upload_parcel", "payload": {"features": [make_point_asset(asset_id="y")]}},
        ],
    )
    assert [a["asset_id"] for a in result["map"]] == ["x", "y"]
