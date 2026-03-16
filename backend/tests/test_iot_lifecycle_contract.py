import unittest

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from backend.main import contracts, API_CONTRACT_VERSION
from backend.routers.fault_router import create_fault_router
from backend.routers.iot_router import create_iot_router
from backend.services.iot_service import (
    normalize_telemetry,
    detect_alerts,
    create_device_registration,
    apply_alert_ack,
    apply_alert_close,
)
from backend.services.live_event_contract_service import build_telemetry_event


class IoTLifecycleContractTests(unittest.TestCase):
    def _with_meta(self, payload: dict, current_user: dict | None) -> dict:
        response_payload: dict = dict(payload)
        response_payload["_meta"] = {
            "api_version": "farm.v1.1.phase2",
            "request_id": "test-request-id",
            "served_at": "2026-03-16T00:00:00Z",
            "user_id": str((current_user or {}).get("id", "")),
        }
        return response_payload

    def _api_error(self, *, status_code: int, error_code: str, message: str, details: dict):
        raise HTTPException(
            status_code=status_code,
            detail={
                "ok": False,
                "error_code": error_code,
                "message": message,
                "details": details,
            },
        )

    def _create_fault_test_client(self, user_state: dict) -> TestClient:
        app = FastAPI()
        test_user: dict = {"id": "test-user"}
        def get_current_user() -> dict:
            return test_user
        def get_user_state(_: str) -> dict:
            return user_state
        def save_user_state(_: str, new_state: dict) -> None:
            user_state.update(new_state)
        def touch_user_state(_: dict) -> None:
            return None
        def find_asset_index_by_id(map_data: list[dict], asset_id: str) -> int:
            for index, item in enumerate(map_data):
                if str(item.get("asset_id", "")) == str(asset_id):
                    return index
            return -1
        def ensure_asset_identity(asset: dict) -> dict:
            ensured: dict = dict(asset)
            ensured["properties"] = dict(ensured.get("properties", {}))
            return ensured
        def build_fault_log_entry(request: object, current_user: dict) -> dict:
            return {
                "log_id": "fault-1",
                "asset_id": str(getattr(request, "asset_id", "")),
                "description": str(getattr(request, "description", "")),
                "severity": str(getattr(request, "severity", "medium")),
                "status": str(getattr(request, "status", "open")),
                "created_at": "2026-03-16T00:00:00Z",
                "resolved_at": str(getattr(request, "resolved_at", "") or ""),
                "user_id": str(current_user.get("id", "")),
                "updates": [],
            }
        app.include_router(
            create_fault_router(
                get_current_user=get_current_user,
                get_user_state=get_user_state,
                save_user_state=save_user_state,
                touch_user_state=touch_user_state,
                find_asset_index_by_id=find_asset_index_by_id,
                ensure_asset_identity=ensure_asset_identity,
                with_meta=self._with_meta,
                api_error=self._api_error,
                build_fault_log_entry=build_fault_log_entry,
            )
        )
        return TestClient(app)

    def _create_iot_test_client(self, user_state: dict) -> TestClient:
        app = FastAPI()
        test_user: dict = {"id": "test-user"}
        def get_current_user() -> dict:
            return test_user
        def get_user_state(_: str) -> dict:
            return user_state
        def save_user_state(_: str, new_state: dict) -> None:
            user_state.update(new_state)
        def touch_user_state(_: dict) -> None:
            return None
        def find_asset_index_by_id(map_data: list[dict], asset_id: str) -> int:
            for index, item in enumerate(map_data):
                if str(item.get("asset_id", "")) == str(asset_id):
                    return index
            return -1
        def ensure_asset_identity(asset: dict) -> dict:
            ensured: dict = dict(asset)
            ensured["properties"] = dict(ensured.get("properties", {}))
            return ensured
        async def broadcast_live_event(_: dict) -> None:
            return None
        def iso_now_utc() -> str:
            return "2026-03-16T00:00:00Z"
        app.include_router(
            create_iot_router(
                get_current_user=get_current_user,
                get_user_state=get_user_state,
                save_user_state=save_user_state,
                touch_user_state=touch_user_state,
                find_asset_index_by_id=find_asset_index_by_id,
                ensure_asset_identity=ensure_asset_identity,
                with_meta=self._with_meta,
                api_error=self._api_error,
                broadcast_live_event=broadcast_live_event,
                iso_now_utc=iso_now_utc,
                live_websocket_clients=[],
                ws_heartbeat_timeout_seconds=45,
                ws_reconnect_hint="reconnect_with_exponential_backoff",
            )
        )
        return TestClient(app)

    def test_contract_discovery_response_shape(self):
        response = contracts({"id": "test-user"})
        self.assertEqual(response["status"], "ok")
        self.assertEqual(response["contract_version"], API_CONTRACT_VERSION)
        self.assertIn("_meta", response)
        self.assertIn("ws_live_schema", response)
        self.assertIn("phase2_endpoints", response)
        self.assertEqual(response["ws_live_schema"]["version"], "ws.live.telemetry.v1")
        endpoint_paths = [item["path"] for item in response["phase2_endpoints"]]
        self.assertIn("/api/v1/iot/telemetry", endpoint_paths)
        self.assertIn("/api/v1/gis/add-fault", endpoint_paths)

    def test_contract_discovery_required_fields(self):
        response = contracts({"id": "test-user"})
        ws_required_fields = response["ws_live_schema"]["required_fields"]
        self.assertIn("schema_version", ws_required_fields)
        self.assertIn("asset_id", ws_required_fields)
        self.assertIn("device_id", ws_required_fields)
        self.assertIn("alerts", ws_required_fields)
        policies = set(response["conflict_policies"])
        self.assertEqual(
            policies,
            {"latest_timestamp_wins", "incoming_wins", "existing_wins"},
        )

    def test_fault_lifecycle_endpoints_return_contract_shape(self):
        user_state: dict = {
            "map": [{"asset_id": "asset-1", "properties": {}}],
            "fault_logs": [],
        }
        client = self._create_fault_test_client(user_state)
        create_response = client.post(
            "/api/v1/gis/add-fault",
            json={
                "asset_id": "asset-1",
                "description": "Nem sensoru arizasi",
                "severity": "high",
            },
        )
        self.assertEqual(create_response.status_code, 200)
        create_body = create_response.json()
        self.assertEqual(create_body["status"], "ok")
        self.assertIn("_meta", create_body)
        self.assertIn("asset_projection", create_body)
        self.assertEqual(create_body["asset_projection"]["open_fault_count"], 1)
        fault_id = create_body["fault"]["log_id"]
        resolve_response = client.patch(
            f"/api/v1/gis/faults/{fault_id}/resolve",
            json={"note": "Sahada cozuldu"},
        )
        self.assertEqual(resolve_response.status_code, 200)
        resolve_body = resolve_response.json()
        self.assertEqual(resolve_body["status"], "ok")
        self.assertIn("_meta", resolve_body)
        self.assertEqual(resolve_body["fault"]["status"], "resolved")
        self.assertEqual(
            resolve_body["contract"]["log_semantics"],
            "asset_projection_plus_event_log.v1",
        )

    def test_iot_alert_ack_close_endpoints_return_contract_shape(self):
        user_state: dict = {
            "map": [],
            "alerts": [
                {
                    "alert_id": "alert-1",
                    "metric": "air_temperature_c",
                    "status": "open",
                }
            ],
        }
        client = self._create_iot_test_client(user_state)
        ack_response = client.patch(
            "/api/v1/iot/alerts/alert-1/ack",
            json={"operator": "op-1"},
        )
        self.assertEqual(ack_response.status_code, 200)
        ack_body = ack_response.json()
        self.assertIn("_meta", ack_body)
        self.assertEqual(ack_body["alert"]["status"], "acked")
        close_response = client.patch(
            "/api/v1/iot/alerts/alert-1/close",
            json={"operator": "op-1", "reason": "kontrol edildi"},
        )
        self.assertEqual(close_response.status_code, 200)
        close_body = close_response.json()
        self.assertIn("_meta", close_body)
        self.assertEqual(close_body["alert"]["status"], "closed")
        self.assertEqual(close_body["alert"]["close_reason"], "kontrol edildi")

    def test_telemetry_quality_fields_exist(self):
        normalized = normalize_telemetry(
            {
                "asset_id": "a1",
                "device_id": "d1",
                "metrics": {"air_temperature_c": 30},
            }
        )
        self.assertIn("quality_flag", normalized)
        self.assertIn("source", normalized)
        self.assertIn("received_at", normalized)
        self.assertIn("ingested_at", normalized)

    def test_device_registration_contains_topic_policy(self):
        reg = create_device_registration(asset_id="asset-x", requested_device_id="dev-x")
        self.assertIn("api_key", reg)
        self.assertIn("topic_policy", reg)
        self.assertIn("telemetry_publish_topic", reg["topic_policy"])
        self.assertIn("command_subscribe_topic", reg["topic_policy"])

    def test_alert_ack_and_close_lifecycle(self):
        alerts = detect_alerts(
            payload={"air_temperature_c": 50},
            thresholds={"air_temperature_max": 40},
        )
        self.assertTrue(len(alerts) > 0)
        alert_id = str(alerts[0]["alert_id"])
        acked = apply_alert_ack(alerts, alert_id, "operator-1")
        self.assertEqual(acked["status"], "acked")
        closed = apply_alert_close(alerts, alert_id, "operator-1", "handled")
        self.assertEqual(closed["status"], "closed")
        self.assertEqual(closed["close_reason"], "handled")

    def test_e2e_contract_shape_telemetry_to_ws(self):
        normalized = normalize_telemetry(
            {
                "asset_id": "asset-z",
                "device_id": "device-z",
                "metrics": {"soil_moisture_pct": 2},
                "quality_flag": "suspect",
                "source": "mqtt",
            }
        )
        alerts = detect_alerts(
            payload={"soil_moisture_pct": 2},
            thresholds={"soil_moisture_min": 10},
        )
        ws_event = build_telemetry_event(
            asset_id=normalized["asset_id"],
            device_id=normalized["device_id"],
            metrics=normalized["metrics"],
            alerts=alerts,
            measured_at=normalized["measured_at"],
        )
        self.assertEqual(ws_event["type"], "telemetry")
        self.assertEqual(ws_event["asset_id"], "asset-z")
        self.assertIn("alerts", ws_event)


if __name__ == "__main__":
    unittest.main()
