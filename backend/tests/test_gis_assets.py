import main as app_module
from conftest import auth_headers, make_point_asset, register_user


def _map(client, headers):
    response = client.get("/api/v1/gis/map", headers=headers)
    assert response.status_code == 200
    return response.json()["map"]


def test_gis_endpoints_require_auth(client):
    assert client.get("/api/v1/gis/map").status_code == 401
    assert client.post("/api/v1/gis/add-asset", json=make_point_asset()).status_code == 401


def test_add_update_delete_asset_by_id(client, headers):
    created = client.post("/api/v1/gis/add-asset", headers=headers, json=make_point_asset()).json()["asset"]
    asset_id = created["asset_id"]
    assert [a["asset_id"] for a in _map(client, headers)] == [asset_id]

    updated_asset = dict(created, name="Yeni Ad")
    update = client.post(
        "/api/v1/gis/update-asset-by-id",
        headers=headers,
        json={"asset_id": asset_id, "asset": updated_asset},
    )
    assert update.status_code == 200, update.text
    assert _map(client, headers)[0]["name"] == "Yeni Ad"

    delete = client.post("/api/v1/gis/delete-asset-by-id", headers=headers, json={"asset_id": asset_id})
    assert delete.status_code == 200
    assert _map(client, headers) == []


def test_update_and_delete_missing_asset_return_404(client, headers):
    update = client.post(
        "/api/v1/gis/update-asset-by-id",
        headers=headers,
        json={"asset_id": "missing", "asset": make_point_asset()},
    )
    assert update.status_code == 404
    delete = client.post("/api/v1/gis/delete-asset-by-id", headers=headers, json={"asset_id": "missing"})
    assert delete.status_code == 404


def test_batch_add_skips_non_dict_items(client, headers):
    response = client.post(
        "/api/v1/gis/batch-add-assets",
        headers=headers,
        json={"assets": [make_point_asset("a"), make_point_asset("b")]},
    )
    assert response.status_code == 200
    assert response.json()["created_count"] == 2
    assert len(_map(client, headers)) == 2


def test_reset_map_clears_assets(client, headers):
    client.post("/api/v1/gis/add-asset", headers=headers, json=make_point_asset())
    assert client.delete("/api/v1/gis/reset-map", headers=headers).status_code == 200
    assert _map(client, headers) == []


def test_snapshot_version_increases_on_mutation(client, headers):
    before = client.get("/api/v1/gis/snapshot", headers=headers).json()["version"]
    client.post("/api/v1/gis/add-asset", headers=headers, json=make_point_asset())
    after = client.get("/api/v1/gis/snapshot", headers=headers).json()["version"]
    assert after == before + 1


def test_legacy_asset_without_id_gets_stable_id(client, user, headers):
    _map(client, headers)
    db = app_module.load_db()
    db["users"][user["user"]["id"]]["map"] = [
        {"name": "eski", "type": "Point", "geometry": {"type": "Point", "coordinates": [1, 2]}, "style": {}, "properties": {}}
    ]
    app_module.save_db(db)
    first = _map(client, headers)[0]["asset_id"]
    second = _map(client, headers)[0]["asset_id"]
    assert first == second
    delete = client.post("/api/v1/gis/delete-asset-by-id", headers=headers, json={"asset_id": first})
    assert delete.status_code == 200


def test_users_cannot_see_each_others_assets(client):
    alice = register_user(client, "alice@example.com")
    bob = register_user(client, "bob@example.com")
    created = client.post("/api/v1/gis/add-asset", headers=auth_headers(alice), json=make_point_asset()).json()["asset"]
    assert _map(client, auth_headers(bob)) == []
    delete = client.post(
        "/api/v1/gis/delete-asset-by-id", headers=auth_headers(bob), json={"asset_id": created["asset_id"]}
    )
    assert delete.status_code == 404
    assert len(_map(client, auth_headers(alice))) == 1
