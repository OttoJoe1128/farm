import datetime
import hashlib

import jwt
import pytest

import main as app_module
from conftest import DEFAULT_PASSWORD, auth_headers, register_user


def test_register_returns_tokens_and_user(client):
    payload = register_user(client, "new@example.com")
    assert payload["token_type"] == "bearer"
    assert payload["access_token"] and payload["refresh_token"]
    assert payload["user"]["email"] == "new@example.com"


def test_first_registered_user_is_not_admin(client):
    first = register_user(client, "first@example.com")
    second = register_user(client, "second@example.com")
    assert first["user"]["role"] == "user"
    assert second["user"]["role"] == "user"


def test_register_rejects_duplicate_email_case_insensitive(client):
    register_user(client, "dup@example.com")
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "DUP@example.com", "username": "x", "password": "p"},
    )
    assert response.status_code == 409


@pytest.mark.parametrize("field", ["email", "username", "password"])
def test_register_rejects_blank_fields(client, field):
    body = {"email": "a@example.com", "username": "a", "password": "p"}
    body[field] = "   "
    assert client.post("/api/v1/auth/register", json=body).status_code == 400


def test_password_is_stored_with_bcrypt(client):
    register_user(client, "hash@example.com")
    stored = app_module.load_users_db()["users"][0]
    assert stored["password_hash"].startswith("$2")
    assert DEFAULT_PASSWORD not in stored["password_hash"]


def test_legacy_sha256_password_still_logs_in_and_is_upgraded(client):
    salt = "legacysalt"
    legacy_hash = hashlib.sha256(f"{salt}:oldpass".encode("utf-8")).hexdigest()
    app_module.save_users_db(
        {
            "users": [
                {
                    "id": "legacy-id",
                    "email": "legacy@example.com",
                    "username": "legacy",
                    "password_salt": salt,
                    "password_hash": legacy_hash,
                    "role": "user",
                }
            ]
        }
    )
    response = client.post(
        "/api/v1/auth/login", json={"email": "legacy@example.com", "password": "oldpass"}
    )
    assert response.status_code == 200, response.text
    assert app_module.load_users_db()["users"][0]["password_hash"].startswith("$2")
    again = client.post(
        "/api/v1/auth/login", json={"email": "legacy@example.com", "password": "oldpass"}
    )
    assert again.status_code == 200


def test_login_success_and_failures(client):
    register_user(client, "login@example.com")
    ok = client.post("/api/v1/auth/login", json={"email": "LOGIN@example.com", "password": DEFAULT_PASSWORD})
    assert ok.status_code == 200
    wrong = client.post("/api/v1/auth/login", json={"email": "login@example.com", "password": "nope"})
    assert wrong.status_code == 401
    unknown = client.post("/api/v1/auth/login", json={"email": "ghost@example.com", "password": "x"})
    assert unknown.status_code == 401
    assert wrong.json()["detail"] == unknown.json()["detail"]


def test_me_requires_valid_access_token(client, user):
    assert client.get("/api/v1/auth/me").status_code == 401
    assert client.get("/api/v1/auth/me", headers={"Authorization": "Bearer garbage"}).status_code == 401
    refresh_as_access = {"Authorization": f"Bearer {user['refresh_token']}"}
    assert client.get("/api/v1/auth/me", headers=refresh_as_access).status_code == 401
    me = client.get("/api/v1/auth/me", headers=auth_headers(user))
    assert me.status_code == 200
    assert me.json()["user"]["email"] == "alice@example.com"


def test_invalid_token_error_does_not_leak_decoder_details(client):
    response = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer not.a.jwt"})
    assert response.status_code == 401
    assert response.json()["detail"] == "Gecersiz token."


def test_expired_access_token_rejected(client, user):
    past = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=5)
    expired = jwt.encode(
        {"sub": user["user"]["id"], "type": "access", "iat": int(past.timestamp()) - 60, "exp": int(past.timestamp())},
        app_module.JWT_SECRET,
        algorithm=app_module.JWT_ALGORITHM,
    )
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {expired}"})
    assert response.status_code == 401


def test_token_signed_with_other_secret_rejected(client, user):
    forged = jwt.encode({"sub": user["user"]["id"], "type": "access", "role": "admin"}, "other-secret", algorithm="HS256")
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {forged}"}).status_code == 401


def test_token_for_deleted_user_rejected(client, user):
    app_module.save_users_db({"users": []})
    assert client.get("/api/v1/auth/me", headers=auth_headers(user)).status_code == 401


def test_refresh_flow(client, user):
    ok = client.post("/api/v1/auth/refresh", json={"refresh_token": user["refresh_token"]})
    assert ok.status_code == 200
    assert ok.json()["access_token"]
    wrong_type = client.post("/api/v1/auth/refresh", json={"refresh_token": user["access_token"]})
    assert wrong_type.status_code == 401


def test_default_admin_from_env_and_admin_guard(client, monkeypatch):
    monkeypatch.setattr(app_module, "DEFAULT_ADMIN_EMAIL", "root@example.com")
    monkeypatch.setattr(app_module, "DEFAULT_ADMIN_PASSWORD", "RootPass1!")
    app_module.ensure_default_admin()
    app_module.ensure_default_admin()
    admins = [u for u in app_module.load_users_db()["users"] if u["email"] == "root@example.com"]
    assert len(admins) == 1 and admins[0]["role"] == "admin"

    admin_login = client.post("/api/v1/auth/login", json={"email": "root@example.com", "password": "RootPass1!"})
    assert admin_login.status_code == 200
    normal = register_user(client, "normal@example.com")

    assert client.get("/api/v1/admin/farms", headers=auth_headers(normal)).status_code == 403
    farms = client.get("/api/v1/admin/farms", headers=auth_headers(admin_login.json()))
    assert farms.status_code == 200


def test_admin_farms_tolerates_items_without_geometry(client, monkeypatch):
    monkeypatch.setattr(app_module, "DEFAULT_ADMIN_EMAIL", "root@example.com")
    monkeypatch.setattr(app_module, "DEFAULT_ADMIN_PASSWORD", "RootPass1!")
    app_module.ensure_default_admin()
    admin = client.post("/api/v1/auth/login", json={"email": "root@example.com", "password": "RootPass1!"}).json()
    app_module.save_db({"users": {"u1": {"map": [{"name": "x", "geometry": None}], "version": 1}}})
    response = client.get("/api/v1/admin/farms", headers=auth_headers(admin))
    assert response.status_code == 200
    assert response.json()["count"] == 1
