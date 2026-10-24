import os

import main as app_module


def test_upload_photo_strips_path_components(client, headers, data_dir):
    response = client.post(
        "/api/v1/gis/upload-photo",
        headers=headers,
        data={"asset_id": "a1"},
        files={"file": ("../../evil.jpg", b"\xff\xd8\xff", "image/jpeg")},
    )
    assert response.status_code == 200, response.text
    url = response.json()["url"]
    assert ".." not in url and url.startswith("/uploads/")
    saved = os.path.join(str(data_dir), url.lstrip("/"))
    assert os.path.isfile(saved)
    assert not os.path.exists(os.path.join(str(data_dir.parent), "evil.jpg"))


def test_upload_photo_rejects_oversized_file(client, headers, monkeypatch):
    monkeypatch.setattr(app_module, "MAX_UPLOAD_BYTES", 10)
    response = client.post(
        "/api/v1/gis/upload-photo",
        headers=headers,
        data={"asset_id": "a1"},
        files={"file": ("big.jpg", b"x" * 11, "image/jpeg")},
    )
    assert response.status_code == 413


def test_upload_map_with_traversal_filename_does_not_escape(client, headers, data_dir):
    response = client.post(
        "/api/v1/gis/upload-map",
        headers=headers,
        files={"file": ("../../escape.geojson", b"{not valid", "application/geo+json")},
    )
    assert response.status_code == 400
    assert not os.path.exists(os.path.join(str(data_dir.parent), "escape.geojson"))
    assert [name for name in os.listdir(str(data_dir)) if name.startswith("temp_upload")] == []


def test_upload_map_error_does_not_leak_exception_text(client, headers):
    response = client.post(
        "/api/v1/gis/upload-map",
        headers=headers,
        files={"file": ("parcel.geojson", b"{not valid", "application/geo+json")},
    )
    assert response.status_code == 400
    assert "error" not in response.json()["detail"].get("details", {})
