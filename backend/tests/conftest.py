import os
import sys
from typing import Any, Dict, Optional

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import main as app_module  # noqa: E402

DEFAULT_PASSWORD = "Secret123!"


@pytest.fixture
def data_dir(tmp_path, monkeypatch):
    work_dir = tmp_path / "work"
    work_dir.mkdir()
    monkeypatch.setattr(app_module, "DB_FILE", str(work_dir / "digital_twin_db.json"))
    monkeypatch.setattr(app_module, "USERS_FILE", str(work_dir / "users_db.json"))
    monkeypatch.chdir(work_dir)
    app_module.live_websocket_clients.clear()
    yield work_dir
    app_module.live_websocket_clients.clear()


@pytest.fixture
def client(data_dir):
    return TestClient(app_module.app)


def register_user(client: TestClient, email: str, password: str = DEFAULT_PASSWORD) -> Dict[str, Any]:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "username": email.split("@")[0], "password": password},
    )
    assert response.status_code == 200, response.text
    return response.json()


def auth_headers(auth_payload: Dict[str, Any]) -> Dict[str, str]:
    return {"Authorization": f"Bearer {auth_payload['access_token']}"}


def make_point_asset(name: str = "Agac 1", asset_id: Optional[str] = None) -> Dict[str, Any]:
    asset: Dict[str, Any] = {
        "name": name,
        "type": "Point",
        "geometry": {"type": "Point", "coordinates": [29.0, 41.0]},
        "style": {"icon": "agac"},
        "properties": {},
    }
    if asset_id is not None:
        asset["properties"]["asset_id"] = asset_id
    return asset


@pytest.fixture
def user(client):
    return register_user(client, "alice@example.com")


@pytest.fixture
def headers(user):
    return auth_headers(user)
