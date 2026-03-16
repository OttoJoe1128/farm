import unittest

from backend.services.iot_service import (
    normalize_telemetry,
    detect_alerts,
    create_device_registration,
    apply_alert_ack,
    apply_alert_close,
)
from backend.services.live_event_contract_service import build_telemetry_event


class IoTLifecycleContractTests(unittest.TestCase):
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
