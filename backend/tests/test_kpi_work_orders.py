import main as app_module
from services.analytics_service import build_kpi
from conftest import make_point_asset


def test_kpi_active_alerts_excludes_closed():
    kpi = build_kpi(
        map_items=[],
        work_orders=[],
        telemetry_log=[],
        alerts=[{"status": "open"}, {"status": "acknowledged"}, {"status": "closed"}],
    )
    assert kpi["active_alerts"] == 2


def test_kpi_counts_turkish_closed_work_order_statuses():
    kpi = build_kpi(
        map_items=[],
        work_orders=[{"status": "open"}, {"status": "tamamlandi"}, {"status": "iptal"}, {"status": "done"}],
        telemetry_log=[],
        alerts=[],
    )
    assert kpi["work_orders_open"] == 1
    assert kpi["work_orders_closed"] == 3


def test_kpi_endpoint(client, user, headers):
    client.post("/api/v1/gis/add-asset", headers=headers, json=make_point_asset())
    state = app_module.get_user_state(user["user"]["id"])
    state["alerts"] = [{"alert_id": "1", "status": "closed"}]
    app_module.save_user_state(user["user"]["id"], state)
    kpi = client.get("/api/v1/analytics/kpi", headers=headers).json()["kpi"]
    assert kpi["assets_total"] == 1
    assert kpi["active_alerts"] == 0


def test_work_order_lifecycle(client, headers):
    created = client.post(
        "/api/v1/work-orders", headers=headers, json={"asset_id": "a1", "title": "Sulama"}
    )
    assert created.status_code == 200, created.text
    item = created.json()["item"]
    assert item["status"] == "open"
    patched = client.patch(
        f"/api/v1/work-orders/{item['work_order_id']}", headers=headers, json={"status": "done", "note": "ok"}
    )
    assert patched.status_code == 200
    assert patched.json()["item"]["status"] == "done"
    listed = client.get("/api/v1/work-orders", headers=headers).json()
    assert listed["count"] == 1


def test_patch_missing_work_order_returns_404(client, headers):
    response = client.patch("/api/v1/work-orders/missing", headers=headers, json={"status": "done"})
    assert response.status_code == 404


def test_device_list_does_not_expose_api_keys(client, headers):
    client.post("/api/v1/gis/add-asset", headers=headers, json=make_point_asset(asset_id="s1"))
    registered = client.post("/api/v1/iot/devices/register", headers=headers, json={"asset_id": "s1", "device_id": "d1"})
    assert registered.status_code == 200
    assert registered.json()["device"]["api_key"]
    devices = client.get("/api/v1/iot/devices", headers=headers).json()["items"]
    assert len(devices) == 1
    assert "api_key" not in devices[0]
