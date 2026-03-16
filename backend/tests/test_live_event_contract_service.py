import unittest

from backend.services.live_event_contract_service import (
    WS_EVENT_SCHEMA_VERSION,
    build_telemetry_event,
)


class LiveEventContractServiceTests(unittest.TestCase):
    def test_build_telemetry_event_has_frozen_keys(self):
        event = build_telemetry_event(
            asset_id="asset-1",
            device_id="dev-1",
            metrics={"soil_moisture_pct": 22.1},
            alerts=[{"metric": "soil_moisture_pct", "rule": "min"}],
            measured_at="2026-03-15T10:20:30Z",
        )
        self.assertEqual(event["schema_version"], WS_EVENT_SCHEMA_VERSION)
        self.assertEqual(event["type"], "telemetry")
        for key in [
            "schema_version",
            "type",
            "asset_id",
            "device_id",
            "metrics",
            "alerts",
            "measured_at",
        ]:
            self.assertIn(key, event)


if __name__ == "__main__":
    unittest.main()
