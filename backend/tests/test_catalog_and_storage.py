import os
import threading

import pytest

import main as app_module
from services.storage import JsonStorage, PostgisStorage, migrate
from conftest import auth_headers, register_user


@pytest.fixture
def headers(client):
    return auth_headers(register_user(client, "catalog@example.com"))


@pytest.fixture
def admin_headers(client, monkeypatch):
    payload = register_user(client, "admin@example.com")
    users = app_module.load_users_db()
    for user in users["users"]:
        if user["email"] == "admin@example.com":
            user["role"] = "admin"
    app_module.save_users_db(users)
    return auth_headers(payload)


def _point(lon, lat, name):
    return {
        "name": name,
        "type": "Point",
        "geometry": {"type": "Point", "coordinates": [lon, lat]},
        "style": {"icon": "agac", "color": "#00FF00"},
        "properties": {},
    }


def test_catalog_requires_auth(client):
    assert client.get("/api/v1/catalog/asset-types").status_code == 401


def test_default_catalog_lists_types_with_forms(client, headers):
    response = client.get("/api/v1/catalog/asset-types", headers=headers)
    assert response.status_code == 200
    types = {t["id"]: t for t in response.json()["types"]}
    assert {"agac", "yapi", "kuyu", "sensor", "gunes", "sera", "sulama_hatti", "cit"} <= set(types)
    assert types["sulama_hatti"]["geometry_types"] == ["LineString"]
    assert types["agac"]["source"] == "default"
    sections = [s["key"] for s in types["agac"]["form"]]
    assert sections[0] == "genel" and "saglik" in sections


def test_unknown_type_is_404(client, headers):
    assert client.get("/api/v1/catalog/asset-types/yok", headers=headers).status_code == 404


def test_only_admin_can_customize_catalog(client, headers, admin_headers):
    body = {
        "id": "ari_kovani",
        "label": "Arı kovanı",
        "icon": "hive",
        "color": "#FFC107",
        "geometry_types": ["Point"],
        "form": [{"key": "kovan", "label": "Kovan", "fields": [
            {"key": "colony_count", "label": "Koloni", "type": "integer", "min": 0, "required": True}
        ]}],
    }
    assert client.put("/api/v1/catalog/asset-types/ari_kovani", json=body, headers=headers).status_code == 403
    created = client.put("/api/v1/catalog/asset-types/ari_kovani", json=body, headers=admin_headers)
    assert created.status_code == 200, created.text
    assert created.json()["source"] == "custom"
    ids = [t["id"] for t in client.get("/api/v1/catalog/asset-types", headers=headers).json()["types"]]
    assert "ari_kovani" in ids
    assert client.delete("/api/v1/catalog/asset-types/ari_kovani", headers=admin_headers).status_code == 200
    assert client.get("/api/v1/catalog/asset-types/ari_kovani", headers=headers).status_code == 404


def test_override_can_disable_default_type(client, headers, admin_headers):
    body = client.get("/api/v1/catalog/asset-types/cit", headers=headers).json()
    body.pop("source")
    body["disabled"] = True
    assert client.put("/api/v1/catalog/asset-types/cit", json=body, headers=admin_headers).status_code == 200
    ids = [t["id"] for t in client.get("/api/v1/catalog/asset-types", headers=headers).json()["types"]]
    assert "cit" not in ids
    reset = client.delete("/api/v1/catalog/asset-types/cit", headers=admin_headers).json()
    assert reset["reverted_to_default"] is True


def test_catalog_rejects_invalid_definitions(client, admin_headers):
    bad = {"id": "x1", "label": "X", "icon": "x", "color": "red", "geometry_types": ["Point"]}
    assert client.put("/api/v1/catalog/asset-types/x1", json=bad, headers=admin_headers).status_code == 422
    mismatch = dict(bad, color="#FFFFFF", id="other")
    assert client.put("/api/v1/catalog/asset-types/x1", json=mismatch, headers=admin_headers).status_code == 422


def test_validate_values_against_form_schema(client, headers):
    response = client.post(
        "/api/v1/catalog/validate",
        json={"type_id": "agac", "values": {
            "agac": {"species": "", "age_years": "2.5", "row_no": "abc"},
            "saglik": {"severity": "felaket"},
        }},
        headers=headers,
    )
    errors = {(e["field"], e["error"]) for e in response.json()["errors"]}
    assert response.json()["valid"] is False
    assert errors == {
        ("agac.species", "required"),
        ("agac.age_years", "not_an_integer"),
        ("agac.row_no", "not_a_number"),
        ("saglik.severity", "invalid_option"),
    }
    ok = client.post(
        "/api/v1/catalog/validate",
        json={"type_id": "agac", "values": {"agac": {"species": "Zeytin", "age_years": 12}}},
        headers=headers,
    )
    assert ok.json() == {"valid": True, "errors": []}


def test_assets_in_bbox_filters_by_geometry_and_user(client, headers):
    for asset in [_point(26.0, 41.0, "icerde"), _point(30.0, 41.0, "disarda")]:
        assert client.post("/api/v1/gis/add-asset", json=asset, headers=headers).status_code == 200
    other = auth_headers(register_user(client, "other@example.com"))
    client.post("/api/v1/gis/add-asset", json=_point(26.0, 41.0, "baskasi"), headers=other)
    response = client.get(
        "/api/v1/gis/assets/in-bbox",
        params={"min_lon": 25.5, "min_lat": 40.5, "max_lon": 26.5, "max_lat": 41.5},
        headers=headers,
    )
    assert response.status_code == 200
    assert [a["name"] for a in response.json()["assets"]] == ["icerde"]
    bad = client.get(
        "/api/v1/gis/assets/in-bbox",
        params={"min_lon": 27, "min_lat": 40, "max_lon": 26, "max_lat": 41},
        headers=headers,
    )
    assert bad.status_code == 422


def test_health_reports_storage_backend(client):
    assert client.get("/health").json()["storage"] == app_module.storage.name


def test_unknown_storage_backend_is_rejected():
    from services.storage import create_storage

    with pytest.raises(RuntimeError):
        create_storage("mongo", database_url="", db_path=lambda: "a", users_path=lambda: "b", lock=threading.RLock())
    with pytest.raises(RuntimeError):
        create_storage("postgis", database_url="", db_path=lambda: "a", users_path=lambda: "b", lock=threading.RLock())


@pytest.mark.skipif(not os.getenv("TEST_DATABASE_URL"), reason="needs TEST_DATABASE_URL (PostGIS)")
def test_migrate_json_to_postgis_roundtrip(tmp_path):
    lock = threading.RLock()
    source = JsonStorage(lambda: str(tmp_path / "db.json"), lambda: str(tmp_path / "users.json"), lock)
    source.save_users({"users": [{"id": "u1", "email": "a@example.com"}, {"id": "u2", "email": "b@example.com"}]})
    state = {"map": [_point(26.0, 41.0, "a"), {"name": "bozuk", "geometry": None}], "version": 3, "updated_at": "t"}
    source.save_user_state("u1", state)
    source.save_catalog_overrides({"ozel": {"id": "ozel"}})
    target = PostgisStorage(os.environ["TEST_DATABASE_URL"])
    target.truncate_all()
    assert migrate(source, target) == {"users": 2, "states": 1, "assets": 2}
    assert target.load_users() == source.load_users()
    assert target.load_user_state("u1") == state
    assert [a["name"] for a in target.assets_in_bbox("u1", (25, 40, 27, 42))] == ["a"]
    assert target.load_catalog_overrides() == {"ozel": {"id": "ozel"}}
