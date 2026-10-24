import json
import os
import threading

import pytest

import main as app_module
from conftest import register_user


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.json_only
def test_json_write_is_atomic_and_leaves_no_temp_files(data_dir):
    target = os.path.join(str(data_dir), "file.json")
    app_module._write_json_file(target, {"a": 1})
    with open(target, encoding="utf-8") as fh:
        assert json.load(fh) == {"a": 1}
    assert os.listdir(str(data_dir)) == ["file.json"]


@pytest.mark.json_only
def test_corrupt_db_is_not_silently_overwritten(client, headers, data_dir):
    with open(app_module.DB_FILE, "w", encoding="utf-8") as fh:
        fh.write("{corrupt")
    with pytest.raises(Exception):
        client.get("/api/v1/gis/map", headers=headers)
    with open(app_module.DB_FILE, encoding="utf-8") as fh:
        assert fh.read() == "{corrupt"


def test_concurrent_registrations_are_not_lost(client):
    errors = []

    def worker(index):
        try:
            register_user(client, f"user{index}@example.com")
        except Exception as exc:
            errors.append(exc)

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(15)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert errors == []
    assert len(app_module.load_users_db()["users"]) == 15


def test_cors_does_not_allow_credentials_with_wildcard_origin(client):
    response = client.get("/health", headers={"Origin": "https://evil.example"})
    assert response.headers.get("access-control-allow-credentials") != "true"


def test_cors_wildcard_mixed_with_origins_disables_credentials():
    assert app_module._cors_settings("*,https://app.example") == (["*"], False)
    assert app_module._cors_settings("") == (["*"], False)
    assert app_module._cors_settings("https://a.example, https://b.example") == (
        ["https://a.example", "https://b.example"],
        True,
    )


def test_jwt_secret_required_in_production():
    with pytest.raises(RuntimeError):
        app_module._resolve_jwt_secret({"ENVIRONMENT": "production"})
    assert app_module._resolve_jwt_secret({"ENVIRONMENT": "production", "SECRET_KEY": "s3cret"}) == "s3cret"
    assert app_module._resolve_jwt_secret({}) != ""
