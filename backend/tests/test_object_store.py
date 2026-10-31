import os

import pytest

from services import object_store


class _FakeS3:
    def __init__(self):
        self.objects = {}

    def put_object(self, Bucket, Key, Body, ContentType):
        self.objects[(Bucket, Key)] = (Body, ContentType)

    def generate_presigned_url(self, op, Params, ExpiresIn):
        return f"https://storage.example/{Params['Bucket']}/{Params['Key']}?exp={ExpiresIn}"


@pytest.fixture
def fake_s3(monkeypatch):
    fake = _FakeS3()
    monkeypatch.setattr(object_store, "_client", lambda: fake)
    monkeypatch.setenv("AWS_ENDPOINT_URL_S3", "https://storage.example")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "key")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "secret")
    return fake


def _auth(client):
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "obj@example.com", "username": "obj", "password": "Test-12345"},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_is_disabled_without_env(monkeypatch):
    for name in ("AWS_ENDPOINT_URL_S3", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"):
        monkeypatch.delenv(name, raising=False)
    assert object_store.is_enabled() is False


def test_safe_key_strips_unsafe_characters():
    assert object_store.safe_key("../u/1", "a.jpg") == "assets/u1/a.jpg"
    assert object_store.safe_key("///", "a.jpg") is None


def test_upload_photo_goes_to_object_storage_not_disk(client, data_dir, fake_s3):
    headers = _auth(client)
    response = client.post(
        "/api/v1/gis/upload-photo",
        headers=headers,
        data={"asset_id": "a1"},
        files={"file": ("foto.jpg", b"\xff\xd8\xff-test", "image/jpeg")},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["url"].startswith("https://storage.example/photos/assets/")
    assert len(fake_s3.objects) == 1
    ((bucket, key), (content, content_type)) = next(iter(fake_s3.objects.items()))
    assert bucket == "photos" and content == b"\xff\xd8\xff-test" and content_type == "image/jpeg"
    assert not os.path.exists(os.path.join(str(data_dir), "uploads"))

    fresh = client.get(f"/api/v1/gis/media/{body['media_id']}/url", headers=headers)
    assert fresh.status_code == 200
    assert fresh.json()["url"].startswith("https://storage.example/photos/")


def test_media_url_unknown_id_is_404(client, data_dir):
    headers = _auth(client)
    response = client.get("/api/v1/gis/media/yok/url", headers=headers)
    assert response.status_code == 404
