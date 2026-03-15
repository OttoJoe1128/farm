import unittest

from backend.services.conflict_policy_service import resolve_asset_conflict


class ConflictPolicyServiceTests(unittest.TestCase):
    def _asset(self, updated_at: str, name: str) -> dict:
        return {
            "name": name,
            "type": "Point",
            "geometry": {"type": "Point", "coordinates": [26.55, 41.67]},
            "style": {"color": "#FF0000", "icon": "agac"},
            "properties": {
                "timestamps": {
                    "created_at": "2026-01-01T00:00:00Z",
                    "updated_at": updated_at,
                }
            },
        }

    def test_latest_timestamp_wins_prefers_newer(self):
        existing = self._asset("2026-01-01T00:00:00Z", "Eski")
        incoming = self._asset("2026-01-02T00:00:00Z", "Yeni")
        result = resolve_asset_conflict(existing, incoming, "latest_timestamp_wins")
        self.assertEqual(result["policy_applied"], "latest_timestamp_wins")
        self.assertEqual(result["resolved_asset"]["name"], "Yeni")

    def test_incoming_wins_forces_incoming(self):
        existing = self._asset("2026-01-03T00:00:00Z", "EskiAmaYeniTarih")
        incoming = self._asset("2026-01-01T00:00:00Z", "Incoming")
        result = resolve_asset_conflict(existing, incoming, "incoming_wins")
        self.assertEqual(result["policy_applied"], "incoming_wins")
        self.assertEqual(result["resolved_asset"]["name"], "Incoming")

    def test_existing_wins_forces_existing(self):
        existing = self._asset("2026-01-01T00:00:00Z", "Existing")
        incoming = self._asset("2026-01-02T00:00:00Z", "Incoming")
        result = resolve_asset_conflict(existing, incoming, "existing_wins")
        self.assertEqual(result["policy_applied"], "existing_wins")
        self.assertEqual(result["resolved_asset"]["name"], "Existing")

    def test_unknown_policy_falls_back(self):
        existing = self._asset("2026-01-01T00:00:00Z", "Existing")
        incoming = self._asset("2026-01-02T00:00:00Z", "Incoming")
        result = resolve_asset_conflict(existing, incoming, "unknown_policy")
        self.assertEqual(result["policy_applied"], "latest_timestamp_wins")
        self.assertEqual(result["resolved_asset"]["name"], "Incoming")


if __name__ == "__main__":
    unittest.main()
