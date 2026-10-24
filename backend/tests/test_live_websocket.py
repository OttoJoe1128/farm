import pytest
from starlette.websockets import WebSocketDisconnect

import main as app_module
from conftest import auth_headers, make_point_asset, register_user
from services.live_event_contract_service import WS_EVENT_SCHEMA_VERSION


def _auth(ws, token):
    ws.send_json({"type": "auth", "token": token})


def _add_asset(client, headers, asset_id):
    response = client.post("/api/v1/gis/add-asset", headers=headers, json=make_point_asset(asset_id=asset_id))
    assert response.status_code == 200


def test_ws_rejects_missing_token(client):
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/ws/live") as ws:
            ws.send_json({"type": "ping", "schema_version": WS_EVENT_SCHEMA_VERSION})
            assert ws.receive_json()["type"] == "unauthorized"
            ws.receive_json()
    assert exc_info.value.code == 4401
    assert app_module.live_websocket_clients == []


def test_ws_rejects_invalid_token(client):
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/ws/live") as ws:
            _auth(ws, "garbage")
            assert ws.receive_json()["type"] == "unauthorized"
            ws.receive_json()
    assert exc_info.value.code == 4401


def test_ws_query_token_is_not_accepted(client, user):
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect(f"/ws/live?token={user['access_token']}") as ws:
            ws.send_json({"type": "ping", "schema_version": WS_EVENT_SCHEMA_VERSION})
            assert ws.receive_json()["type"] == "unauthorized"
            ws.receive_json()
    assert exc_info.value.code == 4401


def test_ws_connects_with_valid_token_and_answers_ping(client, user):
    with client.websocket_connect("/ws/live") as ws:
        _auth(ws, user["access_token"])
        connected = ws.receive_json()
        assert connected["type"] == "connected"
        assert connected["schema_version"] == WS_EVENT_SCHEMA_VERSION
        ws.send_json({"type": "ping", "schema_version": WS_EVENT_SCHEMA_VERSION})
        assert ws.receive_json()["type"] == "pong"


def test_ws_schema_mismatch_closes_with_4001(client, user):
    with client.websocket_connect("/ws/live") as ws:
        _auth(ws, user["access_token"])
        ws.receive_json()
        ws.send_json({"type": "ping", "schema_version": "ws.live.telemetry.v0"})
        assert ws.receive_json()["type"] == "schema_mismatch"
        with pytest.raises(WebSocketDisconnect) as exc_info:
            ws.receive_json()
        assert exc_info.value.code == 4001


def test_ws_client_disconnect_is_clean_and_unregisters(client, user):
    with client.websocket_connect("/ws/live") as ws:
        _auth(ws, user["access_token"])
        ws.receive_json()
        assert len(app_module.live_websocket_clients) == 1
    assert len(app_module.live_websocket_clients) == 0


def test_ws_ignores_non_json_messages(client, user):
    with client.websocket_connect("/ws/live") as ws:
        _auth(ws, user["access_token"])
        ws.receive_json()
        ws.send_text("not json")
        ws.send_json({"type": "ping", "schema_version": WS_EVENT_SCHEMA_VERSION})
        assert ws.receive_json()["type"] == "pong"


def test_telemetry_is_broadcast_only_to_owner(client):
    alice = register_user(client, "alice@example.com")
    bob = register_user(client, "bob@example.com")
    _add_asset(client, auth_headers(alice), "sensor-a")
    with client.websocket_connect("/ws/live") as ws_a, client.websocket_connect("/ws/live") as ws_b:
        _auth(ws_a, alice["access_token"])
        _auth(ws_b, bob["access_token"])
        ws_a.receive_json()
        ws_b.receive_json()
        response = client.post(
            "/api/v1/iot/telemetry",
            headers=auth_headers(alice),
            json={"asset_id": "sensor-a", "device_id": "dev-1", "metrics": {"soil_moisture": 40}},
        )
        assert response.status_code == 200, response.text
        event = ws_a.receive_json()
        assert event["type"] == "telemetry"
        assert event["asset_id"] == "sensor-a"
        ws_b.send_json({"type": "ping", "schema_version": WS_EVENT_SCHEMA_VERSION})
        assert ws_b.receive_json()["type"] == "pong"
