"""Pluggable persistence for backend/main.py.

STORAGE_BACKEND=json    (default) -> JSON files (DB_FILE / USERS_FILE)
STORAGE_BACKEND=postgis           -> PostgreSQL + PostGIS (DATABASE_URL)

Both backends expose the same document-shaped API so request handlers stay
storage-agnostic. PostGIS additionally normalizes map items into an `assets`
table with a GIST-indexed geometry column for spatial queries.
"""
from __future__ import annotations

import contextlib
import datetime
import json
import os
import tempfile
import threading
from typing import Any, Callable, Dict, List, Optional, Sequence, Tuple

from shapely.geometry import box, shape

BBox = Tuple[float, float, float, float]


def _read_json(path: str, default_value: Any, lock: threading.RLock) -> Any:
    with lock:
        if not os.path.exists(path):
            return default_value
        with open(path, "r", encoding="utf-8") as file_obj:
            try:
                return json.load(file_obj)
            except json.JSONDecodeError as decode_error:
                raise RuntimeError(f"Veri dosyasi bozuk: {path}") from decode_error


def _write_json(path: str, payload: Any, lock: threading.RLock) -> None:
    target_dir: str = os.path.dirname(os.path.abspath(path))
    with lock:
        fd, temp_path = tempfile.mkstemp(dir=target_dir, prefix=".tmp_", suffix=".json")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as file_obj:
                json.dump(payload, file_obj, ensure_ascii=False)
                file_obj.flush()
                os.fsync(file_obj.fileno())
            os.replace(temp_path, path)
        except BaseException:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise


def _intersects_bbox(item: Dict[str, Any], bbox: BBox) -> bool:
    try:
        return shape(item.get("geometry") or {}).intersects(box(*bbox))
    except Exception:
        return False


def _valid_geojson(geometry: Any) -> Optional[str]:
    if not isinstance(geometry, dict):
        return None
    try:
        geom = shape(geometry)
    except Exception:
        return None
    if geom.is_empty:
        return None
    return json.dumps(geometry)


class JsonStorage:
    name = "json"

    def __init__(
        self,
        db_path: Callable[[], str],
        users_path: Callable[[], str],
        lock: threading.RLock,
        catalog_path: Optional[Callable[[], str]] = None,
    ) -> None:
        self._db_path = db_path
        self._users_path = users_path
        self._lock = lock
        self._catalog_path = catalog_path or (
            lambda: os.path.join(os.path.dirname(os.path.abspath(self._db_path())), "asset_catalog_db.json")
        )

    def _load_db(self) -> Dict[str, Any]:
        raw: Any = _read_json(self._db_path(), {"users": {}}, self._lock)
        if isinstance(raw, list):
            return {
                "users": {
                    "legacy": {
                        "map": raw,
                        "version": 1,
                        "updated_at": datetime.datetime.utcnow().isoformat(),
                        "processed_op_ids": [],
                    }
                }
            }
        if not isinstance(raw, dict):
            return {"users": {}}
        if not isinstance(raw.get("users"), dict):
            raw["users"] = {}
        return raw

    def load_users(self) -> Dict[str, Any]:
        return _read_json(self._users_path(), {"users": []}, self._lock)

    def save_users(self, payload: Dict[str, Any]) -> None:
        _write_json(self._users_path(), payload, self._lock)

    def load_user_state(self, user_id: str) -> Optional[Dict[str, Any]]:
        state: Any = self._load_db()["users"].get(user_id)
        return state if isinstance(state, dict) else None

    def save_user_state(self, user_id: str, state: Dict[str, Any]) -> None:
        with self._lock:
            db_data = self._load_db()
            db_data["users"][user_id] = state
            _write_json(self._db_path(), db_data, self._lock)

    def all_user_states(self) -> Dict[str, Dict[str, Any]]:
        return {
            uid: state
            for uid, state in self._load_db()["users"].items()
            if isinstance(state, dict)
        }

    def assets_in_bbox(self, user_id: str, bbox: BBox) -> List[Dict[str, Any]]:
        state = self.load_user_state(user_id) or {}
        return [
            item
            for item in state.get("map", [])
            if isinstance(item, dict) and _intersects_bbox(item, bbox)
        ]

    def load_catalog_overrides(self) -> Dict[str, Dict[str, Any]]:
        raw: Any = _read_json(self._catalog_path(), {}, self._lock)
        return raw if isinstance(raw, dict) else {}

    def save_catalog_overrides(self, overrides: Dict[str, Dict[str, Any]]) -> None:
        _write_json(self._catalog_path(), overrides, self._lock)


POSTGIS_SCHEMA = """
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE TABLE IF NOT EXISTS sf_users (
    id TEXT PRIMARY KEY,
    position INTEGER NOT NULL,
    email TEXT,
    doc JSONB NOT NULL
);
CREATE TABLE IF NOT EXISTS sf_user_states (
    user_id TEXT PRIMARY KEY,
    version INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT,
    doc JSONB NOT NULL
);
CREATE TABLE IF NOT EXISTS sf_assets (
    user_id TEXT NOT NULL REFERENCES sf_user_states(user_id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    asset_id TEXT,
    name TEXT,
    geom geometry(Geometry, 4326),
    doc JSONB NOT NULL,
    PRIMARY KEY (user_id, position)
);
CREATE INDEX IF NOT EXISTS sf_assets_geom_idx ON sf_assets USING GIST (geom);
CREATE INDEX IF NOT EXISTS sf_assets_asset_id_idx ON sf_assets (user_id, asset_id);
CREATE TABLE IF NOT EXISTS sf_asset_catalog (
    type_id TEXT PRIMARY KEY,
    doc JSONB NOT NULL
);
"""


class PostgisStorage:
    name = "postgis"

    def __init__(self, database_url: str) -> None:
        import psycopg
        from psycopg.types.json import Jsonb

        self._psycopg = psycopg
        self._jsonb = Jsonb
        self._url = database_url
        self._local = threading.local()
        with self._conn() as conn:
            conn.execute(POSTGIS_SCHEMA)

    @contextlib.contextmanager
    def _conn(self):
        conn = getattr(self._local, "conn", None)
        if conn is None or conn.closed:
            conn = self._psycopg.connect(self._url, autocommit=True)
            self._local.conn = conn
        yield conn

    def _rows(self, sql: str, params: Sequence[Any] = ()) -> List[Tuple[Any, ...]]:
        with self._conn() as conn:
            return list(conn.execute(sql, params).fetchall())

    def truncate_all(self) -> None:
        with self._conn() as conn:
            conn.execute("TRUNCATE sf_assets, sf_user_states, sf_users, sf_asset_catalog")

    def load_users(self) -> Dict[str, Any]:
        rows = self._rows("SELECT doc FROM sf_users ORDER BY position")
        return {"users": [row[0] for row in rows]}

    def save_users(self, payload: Dict[str, Any]) -> None:
        users: List[Any] = [u for u in payload.get("users", []) if isinstance(u, dict)]
        with self._conn() as conn:
            with conn.transaction():
                conn.execute("DELETE FROM sf_users")
                with conn.cursor() as cur:
                    cur.executemany(
                        "INSERT INTO sf_users (id, position, email, doc) VALUES (%s, %s, %s, %s)",
                        [
                            (str(u.get("id")), pos, u.get("email"), self._jsonb(u))
                            for pos, u in enumerate(users)
                        ],
                    )

    def load_user_state(self, user_id: str) -> Optional[Dict[str, Any]]:
        rows = self._rows("SELECT doc FROM sf_user_states WHERE user_id = %s", (user_id,))
        if not rows:
            return None
        state: Dict[str, Any] = dict(rows[0][0])
        state["map"] = [
            row[0]
            for row in self._rows(
                "SELECT doc FROM sf_assets WHERE user_id = %s ORDER BY position", (user_id,)
            )
        ]
        return state

    def save_user_state(self, user_id: str, state: Dict[str, Any]) -> None:
        doc: Dict[str, Any] = {k: v for k, v in state.items() if k != "map"}
        items: List[Dict[str, Any]] = [i for i in state.get("map", []) if isinstance(i, dict)]
        with self._conn() as conn:
            with conn.transaction():
                conn.execute(
                    """
                    INSERT INTO sf_user_states (user_id, version, updated_at, doc)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (user_id) DO UPDATE
                    SET version = EXCLUDED.version, updated_at = EXCLUDED.updated_at, doc = EXCLUDED.doc
                    """,
                    (user_id, int(state.get("version") or 0), state.get("updated_at"), self._jsonb(doc)),
                )
                conn.execute("DELETE FROM sf_assets WHERE user_id = %s", (user_id,))
                with conn.cursor() as cur:
                    cur.executemany(
                        """
                        INSERT INTO sf_assets (user_id, position, asset_id, name, geom, doc)
                        VALUES (%s, %s, %s, %s,
                                ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326), %s)
                        """,
                        [
                            (
                                user_id,
                                pos,
                                item.get("asset_id"),
                                item.get("name"),
                                _valid_geojson(item.get("geometry")),
                                self._jsonb(item),
                            )
                            for pos, item in enumerate(items)
                        ],
                    )

    def all_user_states(self) -> Dict[str, Dict[str, Any]]:
        result: Dict[str, Dict[str, Any]] = {}
        for (user_id,) in self._rows("SELECT user_id FROM sf_user_states ORDER BY user_id"):
            state = self.load_user_state(user_id)
            if state is not None:
                result[user_id] = state
        return result

    def assets_in_bbox(self, user_id: str, bbox: BBox) -> List[Dict[str, Any]]:
        rows = self._rows(
            """
            SELECT doc FROM sf_assets
            WHERE user_id = %s AND geom && ST_MakeEnvelope(%s, %s, %s, %s, 4326)
              AND ST_Intersects(geom, ST_MakeEnvelope(%s, %s, %s, %s, 4326))
            ORDER BY position
            """,
            (user_id, *bbox, *bbox),
        )
        return [row[0] for row in rows]

    def load_catalog_overrides(self) -> Dict[str, Dict[str, Any]]:
        return {row[0]: row[1] for row in self._rows("SELECT type_id, doc FROM sf_asset_catalog")}

    def save_catalog_overrides(self, overrides: Dict[str, Dict[str, Any]]) -> None:
        with self._conn() as conn:
            with conn.transaction():
                conn.execute("DELETE FROM sf_asset_catalog")
                with conn.cursor() as cur:
                    cur.executemany(
                        "INSERT INTO sf_asset_catalog (type_id, doc) VALUES (%s, %s)",
                        [(type_id, self._jsonb(doc)) for type_id, doc in overrides.items()],
                    )


def create_storage(
    backend: str,
    *,
    database_url: str,
    db_path: Callable[[], str],
    users_path: Callable[[], str],
    lock: threading.RLock,
):
    backend = (backend or "json").strip().lower()
    if backend == "json":
        return JsonStorage(db_path, users_path, lock)
    if backend == "postgis":
        if database_url.strip() == "":
            raise RuntimeError("STORAGE_BACKEND=postgis icin DATABASE_URL gerekli.")
        return PostgisStorage(database_url)
    raise RuntimeError(f"Bilinmeyen STORAGE_BACKEND: {backend}")


def migrate(source: Any, target: Any) -> Dict[str, int]:
    """Copies users, per-user states and catalog overrides from source to target."""
    users = source.load_users()
    target.save_users(users)
    states = source.all_user_states()
    for user_id, state in states.items():
        target.save_user_state(user_id, state)
    target.save_catalog_overrides(source.load_catalog_overrides())
    return {
        "users": len(users.get("users", [])),
        "states": len(states),
        "assets": sum(len(s.get("map", [])) for s in states.values()),
    }


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Copy JSON storage into PostGIS.")
    parser.add_argument("--db-file", default=os.getenv("DB_FILE", "digital_twin_db.json"))
    parser.add_argument("--users-file", default=os.getenv("USERS_FILE", "users_db.json"))
    parser.add_argument("--database-url", default=os.getenv("DATABASE_URL", ""))
    args = parser.parse_args()
    lock = threading.RLock()
    json_source = JsonStorage(lambda: args.db_file, lambda: args.users_file, lock)
    print(json.dumps(migrate(json_source, PostgisStorage(args.database_url))))
