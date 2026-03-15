from fastapi import FastAPI, HTTPException, UploadFile, File, Depends, WebSocket, WebSocketDisconnect, Form
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Tuple, Optional
import json
import os
import math
import base64
import datetime
import hashlib
import hmac
import uuid
import requests
import cv2
import numpy as np
import jwt
from io import BytesIO
from PIL import Image
from shapely.geometry import shape, Point
from shapely.ops import unary_union
from services.canonical_service import (
    canonicalize_map_items,
    ensure_asset_identity,
    find_asset_index_by_id,
    iso_now_utc,
    merge_by_latest_timestamp,
)
from services.work_order_service import append_work_order, update_work_order
from services.iot_service import normalize_telemetry, detect_alerts
from services.analytics_service import build_kpi
from services.erp_service import run_connector_sync
try:
    from deepforest import main as deepforest_main
except ImportError:
    deepforest_main = None

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_FILE = "digital_twin_db.json"
USERS_FILE = "users_db.json"
MAPBOX_ACCESS_TOKEN = os.getenv("MAPBOX_ACCESS_TOKEN", "")
MAX_IMAGE_DIMENSION = 1200
ESRI_EXPORT_URL = os.getenv(
    "SATELLITE_EXPORT_URL",
    "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export",
)
IMAGERY_PROVIDER_MODE = os.getenv("IMAGERY_PROVIDER_MODE", "auto").lower()
IMAGERY_PROVIDER_PRIORITY = os.getenv("IMAGERY_PROVIDER_PRIORITY", "esri,mapbox,custom_xyz")
REQUEST_TIMEOUT_SECONDS = 90
MIN_BBOX_PADDING_METERS = 2.0
MIN_IMAGE_DIMENSION = 256
TARGET_METERS_PER_PIXEL = 0.30
ESRI_MAX_TILE_DIMENSION = 200
PROVIDER_METADATA_CACHE_SECONDS = 21600
ESRI_TILE_BASE_URL = (
    "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile"
)
CUSTOM_XYZ_TILE_TEMPLATE = os.getenv("CUSTOM_XYZ_TILE_TEMPLATE", "")
CUSTOM_XYZ_TILE_TEMPLATES = os.getenv("CUSTOM_XYZ_TILE_TEMPLATES", "")
WEB_MERCATOR_ORIGIN_SHIFT = 20037508.342789244
WEB_MERCATOR_INITIAL_RESOLUTION = 156543.03392804097
MIN_IMAGERY_YEAR = int(os.getenv("MIN_IMAGERY_YEAR", "2025"))
REQUIRE_KNOWN_FRESHNESS = os.getenv("REQUIRE_KNOWN_FRESHNESS", "false").lower() == "true"
DEFAULT_FREE_XYZ_TEMPLATES: List[str] = [
    "https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}",
    "https://sat01.maps.yandex.net/tiles?l=sat&x={x}&y={y}&z={z}",
    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
]

provider_metadata_cache: Dict[str, Dict[str, Any]] = {}
mapbox_runtime_disabled: bool = False
live_websocket_clients: List[WebSocket] = []
JWT_SECRET = os.getenv("SECRET_KEY", "smartfarm-dev-secret-change-this")
JWT_ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "14"))
DEFAULT_ADMIN_EMAIL = os.getenv("DEFAULT_ADMIN_EMAIL", "")
DEFAULT_ADMIN_PASSWORD = os.getenv("DEFAULT_ADMIN_PASSWORD", "")
DEFAULT_ADMIN_USERNAME = os.getenv("DEFAULT_ADMIN_USERNAME", "admin")
security = HTTPBearer(auto_error=False)

def get_custom_xyz_templates() -> List[str]:
    if CUSTOM_XYZ_TILE_TEMPLATES.strip() != "":
        return [template.strip() for template in CUSTOM_XYZ_TILE_TEMPLATES.split(",") if template.strip() != ""]
    if CUSTOM_XYZ_TILE_TEMPLATE.strip() != "":
        return [CUSTOM_XYZ_TILE_TEMPLATE.strip()]
    return DEFAULT_FREE_XYZ_TEMPLATES

# --- MODELİ YÜKLE ---
tree_model = None
if deepforest_main is not None:
    print("Yapay Zeka Modeli (DeepForest) Hazırlanıyor...")
    tree_model = deepforest_main.deepforest()
    tree_model.use_release() # Hazır eğitilmiş model
    print("✅ MODEL HAZIR!")
else:
    print("UYARI: DeepForest kurulu degil. analyze-satellite endpointi devre disi.")

class Asset(BaseModel):
    name: str
    type: str
    geometry: Dict[str, Any]
    style: Dict[str, Any]
    properties: Dict[str, Any]

class AnalysisRequest(BaseModel):
    parcel_geometries: List[Dict[str, Any]]

class RegisterRequest(BaseModel):
    email: str
    username: str
    password: str

class LoginRequest(BaseModel):
    email: str
    password: str

class RefreshRequest(BaseModel):
    refresh_token: str

class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = None

class SyncOperation(BaseModel):
    client_op_id: str
    type: str
    payload: Dict[str, Any] = {}
    created_at: Optional[str] = None

class SyncRequest(BaseModel):
    base_version: Optional[int] = None
    ops: List[SyncOperation] = []
    sync_requested_at: Optional[str] = None


class AssetMutationRequest(BaseModel):
    asset_id: Optional[str] = None
    asset: Optional[Dict[str, Any]] = None
    merge_policy: Optional[str] = "latest_timestamp_wins"

class BatchAssetCreateRequest(BaseModel):
    assets: List[Dict[str, Any]] = []

class FaultLogCreateRequest(BaseModel):
    asset_id: str
    description: str
    severity: Optional[str] = "medium"
    status: Optional[str] = "open"
    user_id: Optional[str] = None
    created_at: Optional[str] = None
    resolved_at: Optional[str] = None
    photo_url: Optional[str] = None


class FieldIngestRequest(BaseModel):
    features: List[Dict[str, Any]] = []
    gps_points: List[Dict[str, Any]] = []
    tkgm_context: Dict[str, Any] = {}


class WorkOrderCreateRequest(BaseModel):
    asset_id: str
    title: str
    description: Optional[str] = ""
    assignee: Optional[str] = ""
    due_at: Optional[str] = None
    priority: Optional[str] = "normal"


class WorkOrderUpdateRequest(BaseModel):
    status: Optional[str] = None
    assignee: Optional[str] = None
    note: Optional[str] = None


class TelemetryIngestRequest(BaseModel):
    asset_id: str
    device_id: str
    metrics: Dict[str, Any]
    measured_at: Optional[str] = None


class ErpSyncRequest(BaseModel):
    connector: str = "generic"

class FaultResolveRequest(BaseModel):
    resolved_at: Optional[str] = None
    note: Optional[str] = ""
    resolver_user_id: Optional[str] = None

API_CONTRACT_VERSION = "farm.v1.1.phase2"

def _response_meta(current_user: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    request_id = uuid.uuid4().hex
    return {
        "api_version": API_CONTRACT_VERSION,
        "request_id": request_id,
        "served_at": iso_now_utc(),
        "user_id": str(current_user.get("id", "")) if isinstance(current_user, dict) else "",
    }


def _with_meta(payload: Dict[str, Any], current_user: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    out = dict(payload)
    out["_meta"] = _response_meta(current_user)
    return out


def _api_error(status_code: int, error_code: str, message: str, details: Optional[Dict[str, Any]] = None):
    raise HTTPException(
        status_code=status_code,
        detail={
            "ok": False,
            "error_code": error_code,
            "message": message,
            "details": details or {},
            "_meta": _response_meta(None),
        },
    )

def latlon_to_meters(latitude: float, longitude: float) -> List[float]:
    earth_radius: float = 6378137.0
    clamped_latitude: float = max(min(latitude, 85.05112878), -85.05112878)
    x_meters: float = earth_radius * math.radians(longitude)
    y_meters: float = earth_radius * math.log(math.tan(math.pi / 4 + math.radians(clamped_latitude) / 2))
    return [x_meters, y_meters]

def meters_to_latlon(x_meters: float, y_meters: float) -> List[float]:
    earth_radius: float = 6378137.0
    longitude: float = math.degrees(x_meters / earth_radius)
    latitude: float = math.degrees(2 * math.atan(math.exp(y_meters / earth_radius)) - math.pi / 2)
    return [latitude, longitude]

def convert_geometry_to_mercator(parcel_geometry: Dict[str, Any]) -> Dict[str, Any]:
    geometry_type: str = str(parcel_geometry.get("type", ""))
    raw_coordinates: Any = parcel_geometry.get("coordinates", [])
    if geometry_type == "Polygon":
        projected_rings: List[List[List[float]]] = []
        for ring in raw_coordinates:
            projected_ring: List[List[float]] = []
            for point in ring:
                if len(point) < 2:
                    continue
                projected_point: List[float] = latlon_to_meters(latitude=float(point[1]), longitude=float(point[0]))
                projected_ring.append([projected_point[0], projected_point[1]])
            if projected_ring:
                projected_rings.append(projected_ring)
        return {"type": "Polygon", "coordinates": projected_rings}
    if geometry_type == "MultiPolygon":
        projected_polygons: List[List[List[List[float]]]] = []
        for polygon in raw_coordinates:
            projected_rings = []
            for ring in polygon:
                projected_ring = []
                for point in ring:
                    if len(point) < 2:
                        continue
                    projected_point = latlon_to_meters(latitude=float(point[1]), longitude=float(point[0]))
                    projected_ring.append([projected_point[0], projected_point[1]])
                if projected_ring:
                    projected_rings.append(projected_ring)
            if projected_rings:
                projected_polygons.append(projected_rings)
        return {"type": "MultiPolygon", "coordinates": projected_polygons}
    return parcel_geometry

def project_coordinate_to_pixel(
    x_coord: float,
    y_coord: float,
    min_x: float,
    min_y: float,
    max_x: float,
    max_y: float,
    image_width: int,
    image_height: int
) -> List[int]:
    safe_width: float = max(max_x - min_x, 1e-9)
    safe_height: float = max(max_y - min_y, 1e-9)
    pixel_x: int = int(((x_coord - min_x) / safe_width) * (image_width - 1))
    pixel_y: int = int(((max_y - y_coord) / safe_height) * (image_height - 1))
    clamped_x: int = int(np.clip(pixel_x, 0, image_width - 1))
    clamped_y: int = int(np.clip(pixel_y, 0, image_height - 1))
    return [clamped_x, clamped_y]

def build_parcel_alpha_mask(
    parcel_geometries: List[Dict[str, Any]],
    image_width: int,
    image_height: int,
    min_x: float,
    min_y: float,
    max_x: float,
    max_y: float
) -> np.ndarray:
    alpha_mask: np.ndarray = np.zeros((image_height, image_width), dtype=np.uint8)
    for parcel_geometry in parcel_geometries:
        geometry_type: str = str(parcel_geometry.get("type", ""))
        raw_coordinates: Any = parcel_geometry.get("coordinates", [])
        polygon_list: List[Any] = raw_coordinates if geometry_type == "MultiPolygon" else [raw_coordinates]
        for polygon_data in polygon_list:
            if not polygon_data:
                continue
            ring_pixel_points: List[List[List[int]]] = []
            for ring in polygon_data:
                if len(ring) < 3:
                    continue
                ring_points: List[List[int]] = [
                    project_coordinate_to_pixel(
                        x_coord=float(point[0]),
                        y_coord=float(point[1]),
                        min_x=min_x,
                        min_y=min_y,
                        max_x=max_x,
                        max_y=max_y,
                        image_width=image_width,
                        image_height=image_height,
                    )
                    for point in ring
                    if len(point) >= 2
                ]
                if len(ring_points) >= 3:
                    ring_pixel_points.append(ring_points)
            if len(ring_pixel_points) == 0:
                continue
            exterior_points: np.ndarray = np.array(ring_pixel_points[0], dtype=np.int32)
            cv2.fillPoly(alpha_mask, [exterior_points], 255)
            if len(ring_pixel_points) > 1:
                for interior_ring_points in ring_pixel_points[1:]:
                    interior_points: np.ndarray = np.array(interior_ring_points, dtype=np.int32)
                    cv2.fillPoly(alpha_mask, [interior_points], 0)
    return alpha_mask

def log_mask_integrity(masked_image_rgba: np.ndarray, alpha_mask: np.ndarray) -> None:
    outside_mask: np.ndarray = alpha_mask == 0
    outside_opacity_values: np.ndarray = masked_image_rgba[:, :, 3][outside_mask]
    outside_opaque_pixel_count: int = int(np.count_nonzero(outside_opacity_values > 0))
    total_outside_pixel_count: int = int(outside_opacity_values.size)
    if outside_opaque_pixel_count > 0:
        print(
            f"UYARI: Parsel disinda opak piksel bulundu. "
            f"opak={outside_opaque_pixel_count}, toplam_dis_piksel={total_outside_pixel_count}"
        )
        return
    print(
        f"Maske dogrulama basarili: Parsel disinda opak piksel yok. "
        f"toplam_dis_piksel={total_outside_pixel_count}"
    )

def calculate_image_dimension(minx: float, miny: float, maxx: float, maxy: float) -> int:
    extent_width_meters: float = max(maxx - minx, 1.0)
    extent_height_meters: float = max(maxy - miny, 1.0)
    dominant_extent_meters: float = max(extent_width_meters, extent_height_meters)
    calculated_dimension: int = int(dominant_extent_meters / TARGET_METERS_PER_PIXEL)
    return int(max(MIN_IMAGE_DIMENSION, min(MAX_IMAGE_DIMENSION, calculated_dimension)))

def fetch_esri_tile_image(
    tile_minx: float,
    tile_miny: float,
    tile_maxx: float,
    tile_maxy: float,
    tile_width: int,
    tile_height: int,
) -> Image.Image:
    last_error_detail: str = "Esri tile hatasi."
    for image_format in ["png32", "png"]:
        query_params: Dict[str, Any] = {
            "bbox": f"{tile_minx},{tile_miny},{tile_maxx},{tile_maxy}",
            "bboxSR": 3857,
            "imageSR": 3857,
            "size": f"{tile_width},{tile_height}",
            "format": image_format,
            "transparent": "true",
            "f": "image",
        }
        try:
            response = requests.get(ESRI_EXPORT_URL, params=query_params, timeout=REQUEST_TIMEOUT_SECONDS)
            if response.status_code == 200:
                return Image.open(BytesIO(response.content)).convert("RGBA")
            body_preview: str = response.text[:250].replace("\n", " ")
            last_error_detail = (
                f"Esri tile hata status={response.status_code}, format={image_format}, body={body_preview}"
            )
            print(last_error_detail)
        except Exception as e:
            last_error_detail = f"Esri tile istek hatasi format={image_format}, hata={str(e)}"
            print(last_error_detail)
    raise HTTPException(status_code=502, detail=last_error_detail)

def fetch_esri_image_with_tiling(
    minx: float,
    miny: float,
    maxx: float,
    maxy: float,
    width: int,
    height: int,
) -> np.ndarray:
    tile_columns: int = int(math.ceil(width / ESRI_MAX_TILE_DIMENSION))
    tile_rows: int = int(math.ceil(height / ESRI_MAX_TILE_DIMENSION))
    full_image: Image.Image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    total_width: float = max(maxx - minx, 1e-9)
    total_height: float = max(maxy - miny, 1e-9)
    for row in range(tile_rows):
        pixel_y_start: int = int(round((row * height) / tile_rows))
        pixel_y_end: int = int(round(((row + 1) * height) / tile_rows))
        tile_height: int = max(pixel_y_end - pixel_y_start, 1)
        tile_maxy: float = maxy - (pixel_y_start / height) * total_height
        tile_miny: float = maxy - (pixel_y_end / height) * total_height
        for column in range(tile_columns):
            pixel_x_start: int = int(round((column * width) / tile_columns))
            pixel_x_end: int = int(round(((column + 1) * width) / tile_columns))
            tile_width: int = max(pixel_x_end - pixel_x_start, 1)
            tile_minx: float = minx + (pixel_x_start / width) * total_width
            tile_maxx: float = minx + (pixel_x_end / width) * total_width
            tile_image: Image.Image = fetch_esri_tile_image(
                tile_minx=tile_minx,
                tile_miny=tile_miny,
                tile_maxx=tile_maxx,
                tile_maxy=tile_maxy,
                tile_width=tile_width,
                tile_height=tile_height,
            )
            full_image.paste(tile_image, (pixel_x_start, pixel_y_start))
    return np.array(full_image)

def convert_meters_to_pixel(x_meters: float, y_meters: float, zoom_level: int) -> Tuple[float, float]:
    map_size: float = float(256 * (2 ** zoom_level))
    pixel_x: float = ((x_meters + WEB_MERCATOR_ORIGIN_SHIFT) / (2 * WEB_MERCATOR_ORIGIN_SHIFT)) * map_size
    pixel_y: float = ((WEB_MERCATOR_ORIGIN_SHIFT - y_meters) / (2 * WEB_MERCATOR_ORIGIN_SHIFT)) * map_size
    return pixel_x, pixel_y

def fetch_esri_image_from_xyz_tiles(
    minx: float,
    miny: float,
    maxx: float,
    maxy: float,
    width: int,
    height: int,
) -> np.ndarray:
    requested_mpp: float = max((maxx - minx) / max(width, 1), (maxy - miny) / max(height, 1))
    zoom_float: float = math.log2(WEB_MERCATOR_INITIAL_RESOLUTION / max(requested_mpp, 0.01))
    zoom_level: int = int(max(0, min(19, round(zoom_float))))
    min_px_x, max_px_y = convert_meters_to_pixel(minx, miny, zoom_level)
    max_px_x, min_px_y = convert_meters_to_pixel(maxx, maxy, zoom_level)
    left_px: float = min(min_px_x, max_px_x)
    right_px: float = max(min_px_x, max_px_x)
    top_px: float = min(min_px_y, max_px_y)
    bottom_px: float = max(min_px_y, max_px_y)
    tile_min_x: int = int(math.floor(left_px / 256))
    tile_max_x: int = int(math.floor((right_px - 1) / 256))
    tile_min_y: int = int(math.floor(top_px / 256))
    tile_max_y: int = int(math.floor((bottom_px - 1) / 256))
    tile_count_x: int = tile_max_x - tile_min_x + 1
    tile_count_y: int = tile_max_y - tile_min_y + 1
    stitched_image: Image.Image = Image.new("RGBA", (tile_count_x * 256, tile_count_y * 256), (0, 0, 0, 0))
    for tile_y in range(tile_min_y, tile_max_y + 1):
        for tile_x in range(tile_min_x, tile_max_x + 1):
            tile_url: str = f"{ESRI_TILE_BASE_URL}/{zoom_level}/{tile_y}/{tile_x}"
            tile_response = requests.get(tile_url, timeout=REQUEST_TIMEOUT_SECONDS)
            if tile_response.status_code != 200:
                raise HTTPException(
                    status_code=502,
                    detail=f"Esri tile endpoint hatasi status={tile_response.status_code}, z={zoom_level}, x={tile_x}, y={tile_y}",
                )
            tile_image = Image.open(BytesIO(tile_response.content)).convert("RGBA")
            paste_x: int = (tile_x - tile_min_x) * 256
            paste_y: int = (tile_y - tile_min_y) * 256
            stitched_image.paste(tile_image, (paste_x, paste_y))
    crop_left: int = int(round(left_px - (tile_min_x * 256)))
    crop_top: int = int(round(top_px - (tile_min_y * 256)))
    crop_right: int = int(round(right_px - (tile_min_x * 256)))
    crop_bottom: int = int(round(bottom_px - (tile_min_y * 256)))
    cropped_image: Image.Image = stitched_image.crop((crop_left, crop_top, crop_right, crop_bottom))
    resized_image: Image.Image = cropped_image.resize((width, height), Image.BILINEAR)
    return np.array(resized_image)

def fetch_custom_xyz_image_from_tiles(
    minx: float,
    miny: float,
    maxx: float,
    maxy: float,
    width: int,
    height: int,
) -> np.ndarray:
    tile_templates: List[str] = get_custom_xyz_templates()
    if len(tile_templates) == 0:
        raise HTTPException(status_code=503, detail="Custom XYZ tile template tanimli degil.")
    requested_mpp: float = max((maxx - minx) / max(width, 1), (maxy - miny) / max(height, 1))
    zoom_float: float = math.log2(WEB_MERCATOR_INITIAL_RESOLUTION / max(requested_mpp, 0.01))
    zoom_level: int = int(max(0, min(19, round(zoom_float))))
    min_px_x, max_px_y = convert_meters_to_pixel(minx, miny, zoom_level)
    max_px_x, min_px_y = convert_meters_to_pixel(maxx, maxy, zoom_level)
    left_px: float = min(min_px_x, max_px_x)
    right_px: float = max(min_px_x, max_px_x)
    top_px: float = min(min_px_y, max_px_y)
    bottom_px: float = max(min_px_y, max_px_y)
    tile_min_x: int = int(math.floor(left_px / 256))
    tile_max_x: int = int(math.floor((right_px - 1) / 256))
    tile_min_y: int = int(math.floor(top_px / 256))
    tile_max_y: int = int(math.floor((bottom_px - 1) / 256))
    tile_count_x: int = tile_max_x - tile_min_x + 1
    tile_count_y: int = tile_max_y - tile_min_y + 1
    last_error_text: str = "Custom XYZ tile endpoint hatasi."
    for tile_template in tile_templates:
        try:
            stitched_image: Image.Image = Image.new("RGBA", (tile_count_x * 256, tile_count_y * 256), (0, 0, 0, 0))
            for tile_y in range(tile_min_y, tile_max_y + 1):
                for tile_x in range(tile_min_x, tile_max_x + 1):
                    tile_url: str = (
                        tile_template.replace("{z}", str(zoom_level))
                        .replace("{x}", str(tile_x))
                        .replace("{y}", str(tile_y))
                    )
                    tile_response = requests.get(
                        tile_url,
                        timeout=REQUEST_TIMEOUT_SECONDS,
                        headers={"User-Agent": "Mozilla/5.0"},
                    )
                    if tile_response.status_code != 200:
                        raise HTTPException(
                            status_code=502,
                            detail=f"Custom XYZ tile endpoint hatasi status={tile_response.status_code}, z={zoom_level}, x={tile_x}, y={tile_y}",
                        )
                    tile_image = Image.open(BytesIO(tile_response.content)).convert("RGBA")
                    paste_x: int = (tile_x - tile_min_x) * 256
                    paste_y: int = (tile_y - tile_min_y) * 256
                    stitched_image.paste(tile_image, (paste_x, paste_y))
            crop_left: int = int(round(left_px - (tile_min_x * 256)))
            crop_top: int = int(round(top_px - (tile_min_y * 256)))
            crop_right: int = int(round(right_px - (tile_min_x * 256)))
            crop_bottom: int = int(round(bottom_px - (tile_min_y * 256)))
            cropped_image: Image.Image = stitched_image.crop((crop_left, crop_top, crop_right, crop_bottom))
            resized_image: Image.Image = cropped_image.resize((width, height), Image.BILINEAR)
            print(f"Custom XYZ kaynak secildi: {tile_template}")
            return np.array(resized_image)
        except Exception as e:
            last_error_text = str(e)
            print(f"Custom XYZ template hatasi: {tile_template} -> {last_error_text}")
    raise HTTPException(status_code=502, detail=last_error_text)

def fetch_mapbox_image(
    minx: float,
    miny: float,
    maxx: float,
    maxy: float,
    width: int,
    height: int,
) -> np.ndarray:
    global mapbox_runtime_disabled
    if MAPBOX_ACCESS_TOKEN == "":
        raise HTTPException(status_code=503, detail="Mapbox token tanimli degil.")
    south_west: List[float] = meters_to_latlon(x_meters=minx, y_meters=miny)
    north_east: List[float] = meters_to_latlon(x_meters=maxx, y_meters=maxy)
    south: float = south_west[0]
    west: float = south_west[1]
    north: float = north_east[0]
    east: float = north_east[1]
    bbox_str: str = f"{west},{south},{east},{north}"
    url: str = (
        f"https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/"
        f"[{bbox_str}]/{width}x{height}?access_token={MAPBOX_ACCESS_TOKEN}"
    )
    response = requests.get(url, timeout=REQUEST_TIMEOUT_SECONDS)
    if response.status_code != 200:
        body_preview: str = response.text[:250].replace("\n", " ")
        if response.status_code == 401 and "Direct access not allowed" in body_preview:
            mapbox_runtime_disabled = True
        raise HTTPException(
            status_code=502,
            detail=f"Mapbox hata status={response.status_code}, body={body_preview}",
        )
    return np.array(Image.open(BytesIO(response.content)).convert("RGBA"))

def parse_datetime_value(raw_value: Any) -> Optional[float]:
    if isinstance(raw_value, (int, float)):
        value = float(raw_value)
        if value > 1e12:
            return value / 1000.0
        if value > 946684800:
            return value
        return None
    if isinstance(raw_value, str):
        text_value: str = raw_value.strip()
        if text_value == "":
            return None
        try:
            numeric_value: float = float(text_value)
            return parse_datetime_value(numeric_value)
        except Exception:
            pass
        iso_value: str = text_value.replace("Z", "+00:00")
        try:
            return datetime.datetime.fromisoformat(iso_value).timestamp()
        except Exception:
            return None
    return None

def collect_datetime_candidates(data: Any) -> List[float]:
    candidates: List[float] = []
    if isinstance(data, dict):
        for key, value in data.items():
            key_lower: str = str(key).lower()
            if "date" in key_lower or "time" in key_lower or "modified" in key_lower or "created" in key_lower:
                parsed_value: Optional[float] = parse_datetime_value(value)
                if parsed_value is not None:
                    candidates.append(parsed_value)
            candidates.extend(collect_datetime_candidates(value))
    elif isinstance(data, list):
        for item in data:
            candidates.extend(collect_datetime_candidates(item))
    return candidates

def fetch_provider_freshness_timestamp(provider: str) -> Optional[float]:
    try:
        if provider == "mapbox":
            if MAPBOX_ACCESS_TOKEN == "":
                return None
            response = requests.get(
                "https://api.mapbox.com/v4/mapbox.satellite.json",
                params={"access_token": MAPBOX_ACCESS_TOKEN},
                timeout=15,
            )
            if response.status_code != 200:
                return None
            payload: Dict[str, Any] = response.json()
            candidates: List[float] = collect_datetime_candidates(payload)
            return max(candidates) if len(candidates) > 0 else None
        if provider == "esri":
            response = requests.get(
                "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer",
                params={"f": "pjson"},
                timeout=15,
            )
            if response.status_code != 200:
                return None
            payload = response.json()
            candidates = collect_datetime_candidates(payload)
            return max(candidates) if len(candidates) > 0 else None
        if provider == "custom_xyz":
            return None
        return None
    except Exception:
        return None

def get_provider_freshness_timestamp(provider: str) -> Optional[float]:
    now_ts: float = datetime.datetime.utcnow().timestamp()
    cache_entry: Optional[Dict[str, Any]] = provider_metadata_cache.get(provider)
    if cache_entry is not None:
        cached_at: float = float(cache_entry.get("cached_at", 0))
        if now_ts - cached_at < PROVIDER_METADATA_CACHE_SECONDS:
            return cache_entry.get("freshness_ts")
    freshness_ts: Optional[float] = fetch_provider_freshness_timestamp(provider)
    provider_metadata_cache[provider] = {"freshness_ts": freshness_ts, "cached_at": now_ts}
    return freshness_ts

def is_provider_fresh_enough(freshness_ts: Optional[float]) -> bool:
    if freshness_ts is None:
        return not REQUIRE_KNOWN_FRESHNESS
    try:
        freshness_year: int = datetime.datetime.fromtimestamp(freshness_ts).year
        return freshness_year >= MIN_IMAGERY_YEAR
    except Exception:
        return not REQUIRE_KNOWN_FRESHNESS

def resolve_provider_order() -> List[str]:
    if IMAGERY_PROVIDER_MODE in ["mapbox", "esri", "custom_xyz"]:
        preferred_provider: str = IMAGERY_PROVIDER_MODE
        fallback_candidates: List[str] = [provider for provider in ["esri", "mapbox", "custom_xyz"] if provider != preferred_provider]
        providers = [preferred_provider] + fallback_candidates
    else:
        providers = [
            provider.strip().lower()
            for provider in IMAGERY_PROVIDER_PRIORITY.split(",")
            if provider.strip().lower() in ["mapbox", "esri", "custom_xyz"]
        ]
    if len(providers) == 0:
        providers = ["esri", "mapbox", "custom_xyz"]
    available_providers: List[str] = []
    for provider in providers:
        if provider == "mapbox" and MAPBOX_ACCESS_TOKEN == "":
            continue
        if provider == "mapbox" and mapbox_runtime_disabled:
            continue
        if provider == "custom_xyz" and len(get_custom_xyz_templates()) == 0:
            continue
        available_providers.append(provider)
    if len(available_providers) == 0:
        available_providers = ["esri"]
    provider_scores: List[Tuple[str, Optional[float], int]] = []
    for index, provider in enumerate(available_providers):
        provider_scores.append((provider, get_provider_freshness_timestamp(provider), index))
    provider_scores.sort(
        key=lambda item: (item[1] is not None, item[1] if item[1] is not None else -1, -item[2]),
        reverse=True,
    )
    return [provider for provider, _, _ in provider_scores]

def fetch_masked_satellite_image(parcel_geometries: List[Dict[str, Any]]) -> Tuple[np.ndarray, float, float, float, float, int, int, str, Optional[float]]:
    projected_geometries: List[Dict[str, Any]] = [convert_geometry_to_mercator(geo) for geo in parcel_geometries]
    projected_polygons = [shape(geo) for geo in projected_geometries]
    merged_projected_area = unary_union(projected_polygons)
    minx, miny, maxx, maxy = merged_projected_area.bounds
    if maxx - minx < MIN_BBOX_PADDING_METERS:
        center_x: float = (minx + maxx) / 2
        minx = center_x - (MIN_BBOX_PADDING_METERS / 2)
        maxx = center_x + (MIN_BBOX_PADDING_METERS / 2)
    if maxy - miny < MIN_BBOX_PADDING_METERS:
        center_y: float = (miny + maxy) / 2
        miny = center_y - (MIN_BBOX_PADDING_METERS / 2)
        maxy = center_y + (MIN_BBOX_PADDING_METERS / 2)
    width: int = calculate_image_dimension(minx=minx, miny=miny, maxx=maxx, maxy=maxy)
    height: int = width
    image_rgba_np = None
    used_provider: str = "unknown"
    used_provider_freshness_ts: Optional[float] = None
    provider_errors: List[str] = []
    resolved_order: List[str] = resolve_provider_order()
    print(f"Uydu provider sirasi: {resolved_order}")
    for provider in resolved_order:
        provider_freshness_ts: Optional[float] = get_provider_freshness_timestamp(provider)
        if not is_provider_fresh_enough(provider_freshness_ts):
            provider_errors.append(
                f"{provider} reddedildi: min_yil={MIN_IMAGERY_YEAR}, freshness_ts={provider_freshness_ts}"
            )
            continue
        try:
            if provider == "mapbox":
                image_rgba_np = fetch_mapbox_image(
                    minx=minx,
                    miny=miny,
                    maxx=maxx,
                    maxy=maxy,
                    width=width,
                    height=height,
                )
            elif provider == "esri":
                try:
                    image_rgba_np = fetch_esri_image_with_tiling(
                        minx=minx,
                        miny=miny,
                        maxx=maxx,
                        maxy=maxy,
                        width=width,
                        height=height,
                    )
                except Exception as export_error:
                    print(f"Esri export fallback tetiklendi: {export_error}")
                    image_rgba_np = fetch_esri_image_from_xyz_tiles(
                        minx=minx,
                        miny=miny,
                        maxx=maxx,
                        maxy=maxy,
                        width=width,
                        height=height,
                    )
            else:
                image_rgba_np = fetch_custom_xyz_image_from_tiles(
                    minx=minx,
                    miny=miny,
                    maxx=maxx,
                    maxy=maxy,
                    width=width,
                    height=height,
                )
            used_provider = provider
            used_provider_freshness_ts = provider_freshness_ts
            break
        except Exception as e:
            error_text: str = f"{provider} hatasi: {str(e)}"
            print(error_text)
            provider_errors.append(error_text)
    if image_rgba_np is None:
        combined_errors: str = " | ".join(provider_errors) if len(provider_errors) > 0 else "Uydu kaynagi hatasi."
        raise HTTPException(status_code=502, detail=combined_errors)
    alpha_mask = build_parcel_alpha_mask(
        parcel_geometries=projected_geometries,
        image_width=width,
        image_height=height,
        min_x=minx,
        min_y=miny,
        max_x=maxx,
        max_y=maxy,
    )
    image_rgba_np[:, :, 3] = alpha_mask
    log_mask_integrity(masked_image_rgba=image_rgba_np, alpha_mask=alpha_mask)
    return image_rgba_np, minx, miny, maxx, maxy, width, height, used_provider, used_provider_freshness_ts

def _estimate_dominant_row_angle(candidates: List[Tuple[float, float]]) -> Optional[float]:
    if len(candidates) < 6:
        return None
    histogram_bins: int = 36
    histogram: List[int] = [0 for _ in range(histogram_bins)]
    max_pair_distance: float = 120.0
    min_pair_distance: float = 8.0
    for i in range(len(candidates)):
        x1, y1 = candidates[i]
        for j in range(i + 1, len(candidates)):
            x2, y2 = candidates[j]
            dx: float = x2 - x1
            dy: float = y2 - y1
            distance: float = math.hypot(dx, dy)
            if distance < min_pair_distance or distance > max_pair_distance:
                continue
            angle: float = math.degrees(math.atan2(dy, dx)) % 180.0
            bin_index: int = int((angle / 180.0) * histogram_bins) % histogram_bins
            histogram[bin_index] += 1
    best_bin: int = int(np.argmax(np.array(histogram)))
    if histogram[best_bin] < 5:
        return None
    return (best_bin + 0.5) * (180.0 / histogram_bins)

def _snap_tree_candidates_to_grid(candidates: List[Tuple[float, float]]) -> List[Tuple[float, float]]:
    dominant_angle: Optional[float] = _estimate_dominant_row_angle(candidates)
    if dominant_angle is None:
        return candidates
    theta: float = math.radians(dominant_angle)
    cos_t: float = math.cos(theta)
    sin_t: float = math.sin(theta)
    rotated_points: List[Tuple[float, float, float, float]] = []
    for x_coord, y_coord in candidates:
        x_rot: float = x_coord * cos_t + y_coord * sin_t
        y_rot: float = -x_coord * sin_t + y_coord * cos_t
        rotated_points.append((x_coord, y_coord, x_rot, y_rot))
    row_tolerance: float = 10.0
    kept_points: List[Tuple[float, float]] = []
    used_indices: set = set()
    for base_index, (_, _, _, row_value) in enumerate(rotated_points):
        if base_index in used_indices:
            continue
        row_indices: List[int] = []
        for idx, (_, _, _, candidate_row) in enumerate(rotated_points):
            if abs(candidate_row - row_value) <= row_tolerance:
                row_indices.append(idx)
        if len(row_indices) < 3:
            continue
        for idx in row_indices:
            if idx in used_indices:
                continue
            used_indices.add(idx)
            kept_points.append((rotated_points[idx][0], rotated_points[idx][1]))
    if len(kept_points) == 0:
        return candidates
    return kept_points

def _deduplicate_points(candidates: List[Tuple[float, float]], min_distance_px: float) -> List[Tuple[float, float]]:
    if len(candidates) <= 1:
        return candidates
    sorted_points: List[Tuple[float, float]] = sorted(candidates, key=lambda p: (p[0], p[1]))
    selected_points: List[Tuple[float, float]] = []
    min_distance_sq: float = min_distance_px * min_distance_px
    for point_x, point_y in sorted_points:
        is_close: bool = False
        for existing_x, existing_y in selected_points:
            distance_sq: float = (point_x - existing_x) ** 2 + (point_y - existing_y) ** 2
            if distance_sq < min_distance_sq:
                is_close = True
                break
        if not is_close:
            selected_points.append((point_x, point_y))
    return selected_points

def _nearest_neighbor_distances(candidates: List[Tuple[float, float]]) -> List[float]:
    if len(candidates) < 2:
        return []
    distances: List[float] = []
    for i, (x1, y1) in enumerate(candidates):
        nearest: Optional[float] = None
        for j, (x2, y2) in enumerate(candidates):
            if i == j:
                continue
            d = math.hypot(x2 - x1, y2 - y1)
            if nearest is None or d < nearest:
                nearest = d
        if nearest is not None:
            distances.append(nearest)
    return distances

def _filter_orchard_like_points(candidates: List[Tuple[float, float]]) -> List[Tuple[float, float]]:
    if len(candidates) < 6:
        return candidates
    nearest_distances: List[float] = _nearest_neighbor_distances(candidates)
    if len(nearest_distances) == 0:
        return candidates
    plausible_distances: List[float] = [d for d in nearest_distances if 2.0 <= d <= 55.0]
    if len(plausible_distances) < 4:
        return candidates
    median_distance: float = float(np.median(np.array(plausible_distances)))
    if median_distance <= 0:
        return candidates
    min_neighbor_distance: float = 0.50 * median_distance
    max_neighbor_distance: float = 2.00 * median_distance
    filtered_points: List[Tuple[float, float]] = []
    for i, (x1, y1) in enumerate(candidates):
        neighbor_count: int = 0
        for j, (x2, y2) in enumerate(candidates):
            if i == j:
                continue
            d = math.hypot(x2 - x1, y2 - y1)
            if min_neighbor_distance <= d <= max_neighbor_distance:
                neighbor_count += 1
        required_neighbors: int = 2 if len(candidates) >= 60 else 1
        if neighbor_count >= required_neighbors:
            filtered_points.append((x1, y1))
    if len(filtered_points) < max(4, int(len(candidates) * 0.45)):
        return candidates
    return filtered_points

def _adaptive_min_distance(candidates: List[Tuple[float, float]], fallback_distance: float = 2.2) -> float:
    nearest_distances: List[float] = _nearest_neighbor_distances(candidates)
    if len(nearest_distances) < 3:
        return fallback_distance
    plausible: List[float] = [d for d in nearest_distances if 1.2 <= d <= 40.0]
    if len(plausible) < 3:
        return fallback_distance
    median_distance: float = float(np.median(np.array(plausible)))
    return max(fallback_distance, 0.42 * median_distance)

def _fill_grid_gaps(
    candidates: List[Tuple[float, float]],
    blackhat_image: np.ndarray,
) -> List[Tuple[float, float]]:
    if len(candidates) < 8:
        return candidates
    dominant_angle: Optional[float] = _estimate_dominant_row_angle(candidates)
    if dominant_angle is None:
        return candidates
    nearest_distances: List[float] = _nearest_neighbor_distances(candidates)
    plausible_distances: List[float] = [d for d in nearest_distances if 2.0 <= d <= 50.0]
    if len(plausible_distances) < 4:
        return candidates
    median_distance: float = float(np.median(np.array(plausible_distances)))
    if median_distance <= 1.0:
        return candidates
    theta: float = math.radians(dominant_angle)
    cos_t: float = math.cos(theta)
    sin_t: float = math.sin(theta)
    rotated_points: List[Tuple[float, float, float, float]] = []
    for x_coord, y_coord in candidates:
        x_rot: float = x_coord * cos_t + y_coord * sin_t
        y_rot: float = -x_coord * sin_t + y_coord * cos_t
        rotated_points.append((x_coord, y_coord, x_rot, y_rot))
    row_tolerance: float = max(4.0, 0.45 * median_distance)
    row_groups: List[List[Tuple[float, float, float, float]]] = []
    for point in rotated_points:
        assigned: bool = False
        for group in row_groups:
            mean_row: float = float(np.mean(np.array([g[3] for g in group])))
            if abs(point[3] - mean_row) <= row_tolerance:
                group.append(point)
                assigned = True
                break
        if not assigned:
            row_groups.append([point])
    filled_points: List[Tuple[float, float]] = list(candidates)
    image_height: int = int(blackhat_image.shape[0])
    image_width: int = int(blackhat_image.shape[1])
    blackhat_threshold: float = float(np.percentile(blackhat_image, 78))
    for group in row_groups:
        if len(group) < 3:
            continue
        sorted_group = sorted(group, key=lambda item: item[2])
        for idx in range(len(sorted_group) - 1):
            x1_rot: float = sorted_group[idx][2]
            x2_rot: float = sorted_group[idx + 1][2]
            y_rot: float = float((sorted_group[idx][3] + sorted_group[idx + 1][3]) / 2.0)
            gap: float = x2_rot - x1_rot
            if gap < (1.8 * median_distance) or gap > (3.8 * median_distance):
                continue
            expected_steps: int = int(round(gap / median_distance))
            if expected_steps < 2:
                continue
            for step in range(1, expected_steps):
                x_new_rot: float = x1_rot + (gap * (step / expected_steps))
                x_new: float = x_new_rot * cos_t - y_rot * sin_t
                y_new: float = x_new_rot * sin_t + y_rot * cos_t
                px: int = int(round(x_new))
                py: int = int(round(y_new))
                if px < 1 or py < 1 or px >= (image_width - 1) or py >= (image_height - 1):
                    continue
                local_patch = blackhat_image[py - 1 : py + 2, px - 1 : px + 2]
                if float(np.mean(local_patch)) < blackhat_threshold:
                    continue
                filled_points.append((x_new, y_new))
    return filled_points

def detect_simple_tree_candidates(image_rgba_np: np.ndarray) -> List[Tuple[float, float]]:
    image_bgr: np.ndarray = cv2.cvtColor(image_rgba_np, cv2.COLOR_RGBA2BGR)
    hsv_image: np.ndarray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)
    green_mask: np.ndarray = cv2.inRange(hsv_image, (30, 20, 20), (95, 255, 255))
    brown_mask_1: np.ndarray = cv2.inRange(hsv_image, (5, 20, 15), (25, 255, 180))
    dark_mask: np.ndarray = cv2.inRange(hsv_image, (0, 0, 0), (180, 120, 95))
    combined_mask: np.ndarray = cv2.bitwise_or(green_mask, brown_mask_1)
    combined_mask = cv2.bitwise_or(combined_mask, dark_mask)
    # Kucuk koyu fidan noktalarini one cikarmak icin black-hat kullan.
    gray_image: np.ndarray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    blackhat_kernel: np.ndarray = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    blackhat_image: np.ndarray = cv2.morphologyEx(gray_image, cv2.MORPH_BLACKHAT, blackhat_kernel)
    blackhat_threshold: float = float(np.percentile(blackhat_image, 80))
    _, blackhat_mask = cv2.threshold(
        blackhat_image,
        max(10.0, blackhat_threshold),
        255,
        cv2.THRESH_BINARY,
    )
    combined_mask = cv2.bitwise_or(combined_mask, blackhat_mask)
    kernel: np.ndarray = np.ones((3, 3), np.uint8)
    combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_OPEN, kernel, iterations=1)
    combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_CLOSE, kernel, iterations=1)
    component_count, _, stats, centroids = cv2.connectedComponentsWithStats(combined_mask, connectivity=8)
    image_area: int = int(image_rgba_np.shape[0] * image_rgba_np.shape[1])
    min_area: int = max(6, int(image_area * 0.000004))
    max_area: int = max(min_area + 1, int(image_area * 0.0028))
    candidates: List[Tuple[float, float]] = []
    border_margin: int = 4
    image_height: int = int(image_rgba_np.shape[0])
    image_width: int = int(image_rgba_np.shape[1])
    for component_index in range(1, component_count):
        area: int = int(stats[component_index, cv2.CC_STAT_AREA])
        if area < min_area or area > max_area:
            continue
        left_px: int = int(stats[component_index, cv2.CC_STAT_LEFT])
        top_px: int = int(stats[component_index, cv2.CC_STAT_TOP])
        width_px: int = int(stats[component_index, cv2.CC_STAT_WIDTH])
        height_px: int = int(stats[component_index, cv2.CC_STAT_HEIGHT])
        if (
            left_px <= border_margin
            or top_px <= border_margin
            or (left_px + width_px) >= (image_width - border_margin)
            or (top_px + height_px) >= (image_height - border_margin)
        ):
            continue
        bbox_area: float = float(max(width_px * height_px, 1))
        fill_ratio: float = area / bbox_area
        if fill_ratio < 0.10:
            continue
        center_x: float = float(centroids[component_index][0])
        center_y: float = float(centroids[component_index][1])
        candidates.append((center_x, center_y))
    candidates = _deduplicate_points(candidates, min_distance_px=1.6)
    candidates = _filter_orchard_like_points(candidates)
    candidates = _fill_grid_gaps(candidates, blackhat_image=blackhat_image)
    candidates = _snap_tree_candidates_to_grid(candidates)
    candidates = _deduplicate_points(candidates, min_distance_px=_adaptive_min_distance(candidates))
    return candidates

def detect_simple_structure_candidates(image_rgba_np: np.ndarray) -> List[List[Tuple[float, float]]]:
    image_bgr: np.ndarray = cv2.cvtColor(image_rgba_np, cv2.COLOR_RGBA2BGR)
    gray_image: np.ndarray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    blurred: np.ndarray = cv2.GaussianBlur(gray_image, (5, 5), 0)
    adaptive_mask: np.ndarray = cv2.adaptiveThreshold(
        blurred,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV,
        25,
        4,
    )
    edges: np.ndarray = cv2.Canny(blurred, 45, 135)
    combined_mask: np.ndarray = cv2.bitwise_or(adaptive_mask, edges)
    kernel: np.ndarray = np.ones((3, 3), np.uint8)
    combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    contours, _ = cv2.findContours(combined_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    image_area: float = float(image_rgba_np.shape[0] * image_rgba_np.shape[1])
    min_area: float = max(90.0, image_area * 0.00016)
    max_area: float = max(min_area + 1.0, image_area * 0.55)
    candidates: List[List[Tuple[float, float]]] = []
    image_height: int = int(image_rgba_np.shape[0])
    image_width: int = int(image_rgba_np.shape[1])
    border_margin: int = 2
    for contour in contours:
        area: float = cv2.contourArea(contour)
        if area < min_area or area > max_area:
            continue
        perimeter: float = cv2.arcLength(contour, True)
        if perimeter <= 0:
            continue
        approx: np.ndarray = cv2.approxPolyDP(contour, 0.04 * perimeter, True)
        if len(approx) < 3 or len(approx) > 10:
            continue
        if not cv2.isContourConvex(approx):
            continue
        x_box, y_box, width_box, height_box = cv2.boundingRect(approx)
        if (
            x_box <= border_margin
            or y_box <= border_margin
            or (x_box + width_box) >= (image_width - border_margin)
            or (y_box + height_box) >= (image_height - border_margin)
        ):
            continue
        bounding_area: float = float(max(width_box * height_box, 1))
        rectangularity: float = area / bounding_area
        aspect_ratio: float = float(width_box) / float(max(height_box, 1))
        hull: np.ndarray = cv2.convexHull(contour)
        hull_area: float = float(max(cv2.contourArea(hull), 1.0))
        solidity: float = area / hull_area
        min_rect = cv2.minAreaRect(contour)
        min_rect_area: float = float(max(min_rect[1][0] * min_rect[1][1], 1.0))
        oriented_rect_ratio: float = area / min_rect_area
        if (
            rectangularity < 0.50
            or aspect_ratio < 0.25
            or aspect_ratio > 5.0
            or solidity < 0.72
            or oriented_rect_ratio < 0.52
        ):
            continue
        if len(approx) >= 4:
            angle_ok_count: int = 0
            point_list: List[Tuple[float, float]] = [(float(p[0][0]), float(p[0][1])) for p in approx]
            for index in range(len(point_list)):
                p_prev = point_list[index - 1]
                p_curr = point_list[index]
                p_next = point_list[(index + 1) % len(point_list)]
                vec1 = np.array([p_prev[0] - p_curr[0], p_prev[1] - p_curr[1]], dtype=np.float64)
                vec2 = np.array([p_next[0] - p_curr[0], p_next[1] - p_curr[1]], dtype=np.float64)
                norm1 = np.linalg.norm(vec1)
                norm2 = np.linalg.norm(vec2)
                if norm1 < 1e-6 or norm2 < 1e-6:
                    continue
                cos_angle = float(np.dot(vec1, vec2) / (norm1 * norm2))
                cos_angle = max(-1.0, min(1.0, cos_angle))
                angle_deg = math.degrees(math.acos(cos_angle))
                if 35.0 <= angle_deg <= 160.0:
                    angle_ok_count += 1
            if angle_ok_count < max(3, int(len(point_list) * 0.7)):
                continue
        roi = blurred[y_box : y_box + height_box, x_box : x_box + width_box]
        if roi.size > 0:
            texture_std: float = float(np.std(roi))
            if texture_std > 50.0:
                # Yogun dogal doku (agac/bitki) ise yapi adayi olmasin.
                continue
        polygon_pixels: List[Tuple[float, float]] = []
        for point in approx:
            if len(point) == 0:
                continue
            px: float = float(point[0][0])
            py: float = float(point[0][1])
            polygon_pixels.append((px, py))
        if len(polygon_pixels) >= 3:
            candidates.append(polygon_pixels)
    return candidates

def _read_json_file(path: str, default_value: Any) -> Any:
    if not os.path.exists(path):
        return default_value
    try:
        with open(path, "r", encoding="utf-8") as file_obj:
            return json.load(file_obj)
    except Exception:
        return default_value

def _write_json_file(path: str, payload: Any) -> None:
    with open(path, "w", encoding="utf-8") as file_obj:
        json.dump(payload, file_obj, ensure_ascii=False)

def load_users_db() -> Dict[str, Any]:
    raw_data: Any = _read_json_file(USERS_FILE, {"users": []})
    if not isinstance(raw_data, dict):
        return {"users": []}
    users_list: Any = raw_data.get("users", [])
    if not isinstance(users_list, list):
        users_list = []
    return {"users": users_list}

def save_users_db(payload: Dict[str, Any]) -> None:
    _write_json_file(USERS_FILE, payload)

def _hash_password(password: str, salt: str) -> str:
    hash_input: str = f"{salt}:{password}"
    return hashlib.sha256(hash_input.encode("utf-8")).hexdigest()

def _build_user_response(user: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": user.get("id"),
        "email": user.get("email"),
        "username": user.get("username"),
        "role": user.get("role", "user"),
    }

def _find_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    users_db: Dict[str, Any] = load_users_db()
    for user in users_db["users"]:
        if str(user.get("email", "")).lower() == email.lower():
            return user
    return None

def _find_user_by_id(user_id: str) -> Optional[Dict[str, Any]]:
    users_db: Dict[str, Any] = load_users_db()
    for user in users_db["users"]:
        if str(user.get("id")) == str(user_id):
            return user
    return None

def _create_token(user: Dict[str, Any], expires_delta: datetime.timedelta, token_type: str) -> str:
    now_utc: datetime.datetime = datetime.datetime.now(datetime.timezone.utc)
    expires_at: datetime.datetime = now_utc + expires_delta
    payload: Dict[str, Any] = {
        "sub": user.get("id"),
        "role": user.get("role", "user"),
        "type": token_type,
        "iat": int(now_utc.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def _create_auth_payload(user: Dict[str, Any]) -> Dict[str, Any]:
    access_token: str = _create_token(
        user=user,
        expires_delta=datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
        token_type="access",
    )
    refresh_token: str = _create_token(
        user=user,
        expires_delta=datetime.timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
        token_type="refresh",
    )
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": _build_user_response(user),
    }

def _decode_token(token: str, expected_type: str) -> Dict[str, Any]:
    try:
        payload: Dict[str, Any] = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except Exception as decode_error:
        raise HTTPException(status_code=401, detail=f"Gecersiz token: {decode_error}")
    token_type: str = str(payload.get("type", ""))
    if token_type != expected_type:
        raise HTTPException(status_code=401, detail="Token tipi gecersiz.")
    return payload

def ensure_default_admin() -> None:
    if DEFAULT_ADMIN_EMAIL.strip() == "" or DEFAULT_ADMIN_PASSWORD.strip() == "":
        return
    users_db: Dict[str, Any] = load_users_db()
    for user in users_db["users"]:
        if str(user.get("email", "")).lower() == DEFAULT_ADMIN_EMAIL.lower():
            return
    salt: str = uuid.uuid4().hex
    users_db["users"].append(
        {
            "id": uuid.uuid4().hex,
            "email": DEFAULT_ADMIN_EMAIL.strip().lower(),
            "username": DEFAULT_ADMIN_USERNAME.strip(),
            "password_salt": salt,
            "password_hash": _hash_password(DEFAULT_ADMIN_PASSWORD, salt),
            "role": "admin",
            "created_at": datetime.datetime.utcnow().isoformat(),
        }
    )
    save_users_db(users_db)

def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> Dict[str, Any]:
    if credentials is None or str(credentials.credentials).strip() == "":
        raise HTTPException(status_code=401, detail="Yetkilendirme gerekli.")
    payload: Dict[str, Any] = _decode_token(credentials.credentials, "access")
    user_id: str = str(payload.get("sub", ""))
    user: Optional[Dict[str, Any]] = _find_user_by_id(user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="Kullanici bulunamadi.")
    return user

def require_admin(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    if str(current_user.get("role", "user")) != "admin":
        raise HTTPException(status_code=403, detail="Admin yetkisi gerekli.")
    return current_user

def load_db() -> Dict[str, Any]:
    raw_data: Any = _read_json_file(DB_FILE, {"users": {}})
    if isinstance(raw_data, list):
        return {"users": {"legacy": {"map": raw_data, "version": 1, "updated_at": datetime.datetime.utcnow().isoformat(), "processed_op_ids": []}}}
    if not isinstance(raw_data, dict):
        return {"users": {}}
    if not isinstance(raw_data.get("users"), dict):
        raw_data["users"] = {}
    return raw_data

def save_db(data: Dict[str, Any]) -> None:
    _write_json_file(DB_FILE, data)

def _empty_user_state() -> Dict[str, Any]:
    return {
        "map": [],
        "version": 0,
        "updated_at": None,
        "processed_op_ids": [],
        "work_orders": [],
        "telemetry_log": [],
        "alerts": [],
        "integration_jobs": [],
    }

def get_user_state(user_id: str) -> Dict[str, Any]:
    db_data: Dict[str, Any] = load_db()
    users_bucket: Dict[str, Any] = db_data["users"]
    if user_id not in users_bucket or not isinstance(users_bucket[user_id], dict):
        users_bucket[user_id] = _empty_user_state()
        save_db(db_data)
    user_state: Dict[str, Any] = users_bucket[user_id]
    if not isinstance(user_state.get("map"), list):
        user_state["map"] = []
    user_state["map"] = canonicalize_map_items(user_state["map"])
    if not isinstance(user_state.get("processed_op_ids"), list):
        user_state["processed_op_ids"] = []
    if not isinstance(user_state.get("work_orders"), list):
        user_state["work_orders"] = []
    if not isinstance(user_state.get("telemetry_log"), list):
        user_state["telemetry_log"] = []
    if not isinstance(user_state.get("alerts"), list):
        user_state["alerts"] = []
    if not isinstance(user_state.get("integration_jobs"), list):
        user_state["integration_jobs"] = []
    if not isinstance(user_state.get("version"), int):
        user_state["version"] = 0
    return user_state

def save_user_state(user_id: str, user_state: Dict[str, Any]) -> None:
    db_data: Dict[str, Any] = load_db()
    if "users" not in db_data or not isinstance(db_data["users"], dict):
        db_data["users"] = {}
    db_data["users"][user_id] = user_state
    save_db(db_data)

def _touch_user_state(user_state: Dict[str, Any]) -> None:
    user_state["version"] = int(user_state.get("version", 0)) + 1
    user_state["updated_at"] = datetime.datetime.utcnow().isoformat()


def _find_asset_index(map_data: List[Dict[str, Any]], payload: Dict[str, Any]) -> int:
    asset_id_text: str = str(payload.get("asset_id", "")).strip()
    if asset_id_text != "":
        return find_asset_index_by_id(map_data, asset_id_text)
    try:
        index_value = int(payload.get("index", -1))
    except Exception:
        index_value = -1
    if 0 <= index_value < len(map_data):
        return index_value
    return -1

def _extract_parcel_boundary(asset_item: Dict[str, Any]) -> List[List[float]]:
    geometry_obj: Dict[str, Any] = dict(asset_item.get("geometry", {}))
    geometry_type: str = str(geometry_obj.get("type", ""))
    coordinates: Any = geometry_obj.get("coordinates", [])
    if geometry_type == "Polygon" and isinstance(coordinates, list) and len(coordinates) > 0:
        outer_ring: Any = coordinates[0]
    elif geometry_type == "MultiPolygon" and isinstance(coordinates, list) and len(coordinates) > 0:
        first_polygon: Any = coordinates[0]
        outer_ring = first_polygon[0] if isinstance(first_polygon, list) and len(first_polygon) > 0 else []
    else:
        return []
    if not isinstance(outer_ring, list):
        return []
    boundary: List[List[float]] = []
    for point in outer_ring:
        if not isinstance(point, list) or len(point) < 2:
            continue
        boundary.append([float(point[1]), float(point[0])])
    return boundary

def _build_fault_log_entry(request: FaultLogCreateRequest, current_user: Dict[str, Any]) -> Dict[str, Any]:
    event_time: str = request.created_at or iso_now_utc()
    return {
        "log_id": uuid.uuid4().hex,
        "log_type": "fault",
        "event_type": "fault_reported",
        "schema_version": "fault_log.v1",
        "asset_id": str(request.asset_id),
        "description": str(request.description),
        "severity": str(request.severity or "medium"),
        "status": str(request.status or "open"),
        "created_at": event_time,
        "resolved_at": request.resolved_at,
        "photo_url": request.photo_url,
        "reported_by": str(request.user_id or current_user.get("id", "")),
        "updates": [],
    }


async def _broadcast_live_event(event_payload: Dict[str, Any]) -> None:
    if len(live_websocket_clients) == 0:
        return
    disconnected: List[WebSocket] = []
    for client in live_websocket_clients:
        try:
            await client.send_json(event_payload)
        except Exception:
            disconnected.append(client)
    if len(disconnected) > 0:
        for dead_client in disconnected:
            if dead_client in live_websocket_clients:
                live_websocket_clients.remove(dead_client)

ensure_default_admin()

@app.post("/api/v1/auth/register")
def register(request: RegisterRequest):
    email_text: str = request.email.strip().lower()
    username_text: str = request.username.strip()
    password_text: str = request.password.strip()
    if email_text == "" or username_text == "" or password_text == "":
        raise HTTPException(status_code=400, detail="Email, kullanici adi ve sifre zorunlu.")
    if _find_user_by_email(email_text) is not None:
        raise HTTPException(status_code=409, detail="Bu email zaten kayitli.")
    users_db: Dict[str, Any] = load_users_db()
    is_first_user: bool = len(users_db["users"]) == 0
    salt: str = uuid.uuid4().hex
    user_record: Dict[str, Any] = {
        "id": uuid.uuid4().hex,
        "email": email_text,
        "username": username_text,
        "password_salt": salt,
        "password_hash": _hash_password(password_text, salt),
        "role": "admin" if is_first_user else "user",
        "created_at": datetime.datetime.utcnow().isoformat(),
    }
    users_db["users"].append(user_record)
    save_users_db(users_db)
    return _create_auth_payload(user_record)

@app.post("/api/v1/auth/login")
def login(request: LoginRequest):
    email_text: str = request.email.strip().lower()
    password_text: str = request.password.strip()
    user: Optional[Dict[str, Any]] = _find_user_by_email(email_text)
    if user is None:
        raise HTTPException(status_code=401, detail="Kullanici bulunamadi.")
    expected_hash: str = str(user.get("password_hash", ""))
    salt: str = str(user.get("password_salt", ""))
    if not hmac.compare_digest(expected_hash, _hash_password(password_text, salt)):
        raise HTTPException(status_code=401, detail="Sifre hatali.")
    return _create_auth_payload(user)

@app.post("/api/v1/auth/refresh")
def refresh_token(request: RefreshRequest):
    payload: Dict[str, Any] = _decode_token(request.refresh_token, "refresh")
    user: Optional[Dict[str, Any]] = _find_user_by_id(str(payload.get("sub", "")))
    if user is None:
        raise HTTPException(status_code=401, detail="Kullanici bulunamadi.")
    return _create_auth_payload(user)

@app.post("/api/v1/auth/logout")
def logout(request: LogoutRequest):
    return {"status": "ok", "message": "Cikis islemi tamamlandi."}

@app.get("/api/v1/auth/me")
def me(current_user: Dict[str, Any] = Depends(get_current_user)):
    return _with_meta({"status": "ok", "user": _build_user_response(current_user)}, current_user)


@app.get("/api/v1/contracts")
def contracts(current_user: Dict[str, Any] = Depends(get_current_user)):
    return _with_meta(
        {
            "status": "ok",
            "contract_version": API_CONTRACT_VERSION,
            "error_codes": [
                "asset_not_found",
                "fault_not_found",
                "work_order_not_found",
                "version_mismatch",
                "validation_error",
                "unauthorized",
                "forbidden",
            ],
            "phase2_endpoints": [
                {"method": "POST", "path": "/api/v1/field/ingest"},
                {"method": "POST", "path": "/api/v1/gis/add-fault"},
                {"method": "GET", "path": "/api/v1/gis/faults"},
                {"method": "PATCH", "path": "/api/v1/gis/faults/{log_id}/resolve"},
                {"method": "POST", "path": "/api/v1/work-orders"},
                {"method": "POST", "path": "/api/v1/iot/telemetry"},
            ],
            "response_schema": {
                "required": ["status", "_meta"],
                "_meta": ["api_version", "request_id", "served_at", "user_id"],
            },
        },
        current_user,
    )

@app.get("/api/v1/gis/map")
def get_map(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    return canonicalize_map_items(user_state["map"])

@app.get("/api/v1/gis/snapshot")
def get_snapshot(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data = canonicalize_map_items(user_state["map"])
    user_state["map"] = map_data
    return {
        "map": map_data,
        "version": user_state.get("version", 0),
        "updated_at": user_state.get("updated_at"),
    }

@app.delete("/api/v1/gis/reset-map")
def reset_map(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    user_state["map"] = []
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return {"status": "cleared"}

@app.post("/api/v1/gis/upload-map")
async def upload_map(
    file: UploadFile = File(...),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    temp_path: str = f"temp_upload_{file.filename}"
    try:
        with open(temp_path, "wb") as temp_file:
            temp_file.write(await file.read())
        gdf = None
        try:
            import geopandas as gpd
            gdf = gpd.read_file(temp_path)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Dosya okunamadi: {e}")
        if gdf is None or gdf.empty:
            raise HTTPException(status_code=400, detail="Dosyada gecerli geometri bulunamadi.")
        if gdf.crs is not None and str(gdf.crs) != "EPSG:4326":
            gdf = gdf.to_crs("EPSG:4326")
        data: List[Dict[str, Any]] = []
        for index, row in gdf.iterrows():
            geom = row.geometry
            if geom is None:
                continue
            props: Dict[str, Any] = {}
            for key, value in row.drop(labels=["geometry"]).items():
                try:
                    json.dumps(value)
                    props[str(key)] = value
                except Exception:
                    props[str(key)] = str(value)
            feature_name: str = str(props.get("name", f"Parsel {index + 1}"))
            data.append({
                "name": feature_name,
                "type": geom.geom_type,
                "geometry": geom.__geo_interface__,
                "style": {"color": "#8BC34A", "icon": "landscape"},
                "properties": {"iot_connected": False, **props},
            })
        if len(data) == 0:
            raise HTTPException(status_code=400, detail="Dosyada islenebilir geometri bulunamadi.")
        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        current_map: List[Dict[str, Any]] = list(user_state.get("map", []))
        current_map.extend(canonicalize_map_items(data))
        user_state["map"] = current_map
        _touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)
        return {"status": "success", "data": data}
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

@app.post("/api/v1/gis/add-asset")
def add_asset(asset: Asset, current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    new_asset = ensure_asset_identity(asset.dict())
    map_data.append(new_asset)
    user_state["map"] = map_data
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return {"status": "success", "asset": new_asset}

@app.post("/api/v1/gis/batch-add-assets")
def batch_add_assets(
    request: BatchAssetCreateRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    created_assets: List[Dict[str, Any]] = []
    for raw_asset in request.assets:
        if not isinstance(raw_asset, dict):
            continue
        created_asset: Dict[str, Any] = ensure_asset_identity(raw_asset)
        map_data.append(created_asset)
        created_assets.append(created_asset)
    user_state["map"] = map_data
    if len(created_assets) > 0:
        _touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)
    return {
        "status": "ok",
        "created_count": len(created_assets),
        "total_count": len(map_data),
        "assets": created_assets,
    }

@app.post("/api/v1/gis/upload-photo")
async def upload_photo(
    file: UploadFile = File(...),
    asset_id: str = Form(...),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    media_files: List[Dict[str, Any]] = list(user_state.get("media_files", []))
    saved_file_name: str = f"{uuid.uuid4().hex}_{str(file.filename or 'photo.jpg')}"
    upload_dir: str = "uploads"
    os.makedirs(upload_dir, exist_ok=True)
    file_path: str = os.path.join(upload_dir, saved_file_name)
    with open(file_path, "wb") as output_file:
        output_file.write(await file.read())
    photo_url: str = f"/uploads/{saved_file_name}"
    media_files.append(
        {
            "media_id": uuid.uuid4().hex,
            "asset_id": str(asset_id),
            "url": photo_url,
            "content_type": str(file.content_type or "application/octet-stream"),
            "uploaded_at": iso_now_utc(),
            "uploaded_by": str(current_user.get("id", "")),
        }
    )
    user_state["media_files"] = media_files[-2000:]
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return {"status": "ok", "url": photo_url, "asset_id": str(asset_id)}

@app.post("/api/v1/gis/add-fault")
def add_fault_record(
    request: FaultLogCreateRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    target_index: int = find_asset_index_by_id(map_data, request.asset_id)
    if target_index < 0:
        _api_error(
            status_code=404,
            error_code="asset_not_found",
            message="Ariza kaydi eklenecek varlik bulunamadi.",
            details={"asset_id": request.asset_id},
        )
    fault_logs: List[Dict[str, Any]] = list(user_state.get("fault_logs", []))
    fault_log: Dict[str, Any] = _build_fault_log_entry(request, current_user)
    fault_logs.append(fault_log)
    target_asset: Dict[str, Any] = ensure_asset_identity(map_data[target_index])
    properties: Dict[str, Any] = dict(target_asset.get("properties", {}))
    asset_logs: List[Dict[str, Any]] = list(properties.get("logs", []))
    asset_logs.append(
        {
            "id": fault_log["log_id"],
            "type": "fault",
            "description": fault_log["description"],
            "severity": fault_log["severity"],
            "status": fault_log["status"],
            "at": fault_log["created_at"],
        }
    )
    properties["logs"] = asset_logs[-200:]
    open_fault_count: int = 0
    for item in asset_logs:
        if str(item.get("status", "open")) != "resolved":
            open_fault_count += 1
    properties["open_fault_count"] = open_fault_count
    properties["last_fault_at"] = fault_log["created_at"]
    target_asset["properties"] = properties
    map_data[target_index] = ensure_asset_identity(target_asset)
    user_state["fault_logs"] = fault_logs[-5000:]
    user_state["map"] = map_data
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return _with_meta(
        {
            "status": "ok",
            "fault": fault_log,
            "asset_projection": {
                "asset_id": request.asset_id,
                "open_fault_count": open_fault_count,
                "last_fault_at": fault_log["created_at"],
            },
        },
        current_user,
    )


@app.get("/api/v1/gis/faults")
def list_fault_logs(
    asset_id: Optional[str] = None,
    status: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    fault_logs: List[Dict[str, Any]] = list(user_state.get("fault_logs", []))
    results: List[Dict[str, Any]] = []
    for item in fault_logs:
        if not isinstance(item, dict):
            continue
        if asset_id is not None and str(item.get("asset_id", "")) != str(asset_id):
            continue
        if status is not None and str(item.get("status", "")) != str(status):
            continue
        results.append(item)
    return _with_meta(
        {
            "status": "ok",
            "count": len(results),
            "items": results[-1000:],
        },
        current_user,
    )


@app.patch("/api/v1/gis/faults/{log_id}/resolve")
def resolve_fault_log(
    log_id: str,
    request: FaultResolveRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    fault_logs: List[Dict[str, Any]] = list(user_state.get("fault_logs", []))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    target_index: int = -1
    for idx, item in enumerate(fault_logs):
        if str(item.get("log_id", "")) == str(log_id):
            target_index = idx
            break
    if target_index < 0:
        _api_error(
            status_code=404,
            error_code="fault_not_found",
            message="Cozulecek ariza kaydi bulunamadi.",
            details={"log_id": log_id},
        )
    row: Dict[str, Any] = dict(fault_logs[target_index])
    if str(row.get("status", "open")) == "resolved":
        return _with_meta({"status": "ok", "fault": row}, current_user)
    resolved_at = str(request.resolved_at or iso_now_utc())
    row["status"] = "resolved"
    row["resolved_at"] = resolved_at
    updates: List[Dict[str, Any]] = list(row.get("updates", []))
    updates.append(
        {
            "event_type": "fault_resolved",
            "at": resolved_at,
            "resolver_user_id": str(request.resolver_user_id or current_user.get("id", "")),
            "note": str(request.note or ""),
        }
    )
    row["updates"] = updates[-50:]
    fault_logs[target_index] = row
    asset_id: str = str(row.get("asset_id", ""))
    asset_index = find_asset_index_by_id(map_data, asset_id)
    if 0 <= asset_index < len(map_data):
        target_asset: Dict[str, Any] = ensure_asset_identity(map_data[asset_index])
        props: Dict[str, Any] = dict(target_asset.get("properties", {}))
        asset_logs: List[Dict[str, Any]] = list(props.get("logs", []))
        for i, asset_log in enumerate(asset_logs):
            if str(asset_log.get("id", "")) == str(log_id):
                patched = dict(asset_log)
                patched["status"] = "resolved"
                patched["resolved_at"] = resolved_at
                asset_logs[i] = patched
                break
        open_fault_count = 0
        for item in asset_logs:
            if str(item.get("status", "open")) != "resolved":
                open_fault_count += 1
        props["logs"] = asset_logs[-200:]
        props["open_fault_count"] = open_fault_count
        target_asset["properties"] = props
        map_data[asset_index] = ensure_asset_identity(target_asset)
        user_state["map"] = map_data
    user_state["fault_logs"] = fault_logs[-5000:]
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return _with_meta({"status": "ok", "fault": row}, current_user)

@app.get("/api/v1/gis/parcels")
def list_parcels(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = canonicalize_map_items(list(user_state.get("map", [])))
    parcels: List[Dict[str, Any]] = []
    for asset_item in map_data:
        if not isinstance(asset_item, dict):
            continue
        geometry_obj: Dict[str, Any] = dict(asset_item.get("geometry", {}))
        geometry_type: str = str(geometry_obj.get("type", ""))
        if geometry_type not in ("Polygon", "MultiPolygon"):
            continue
        parcel_id: str = str(
            asset_item.get("asset_id")
            or asset_item.get("id")
            or uuid.uuid4().hex
        )
        parcel_name: str = str(asset_item.get("name") or "Adsiz Parsel")
        boundary: List[List[float]] = _extract_parcel_boundary(asset_item)
        parcels.append({"id": parcel_id, "name": parcel_name, "boundary": boundary})
    return parcels

@app.put("/api/v1/gis/update-asset/{index}")
def update_asset(index: int, asset: Asset, current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    if index < 0 or index >= len(map_data):
        raise HTTPException(status_code=404, detail="Asset not found")
    existing_asset = ensure_asset_identity(map_data[index])
    incoming_asset = ensure_asset_identity(asset.dict())
    map_data[index] = merge_by_latest_timestamp(existing_asset, incoming_asset)
    user_state["map"] = map_data
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return {"status": "updated"}

@app.delete("/api/v1/gis/delete-asset/{index}")
def delete_asset(index: int, current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    if index < 0 or index >= len(map_data):
        raise HTTPException(status_code=404, detail="Asset not found")
    map_data.pop(index)
    user_state["map"] = map_data
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return {"status": "deleted"}


@app.post("/api/v1/gis/update-asset-by-id")
def update_asset_by_id(
    request: AssetMutationRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    asset_id: str = str(request.asset_id or "").strip()
    if asset_id == "" or request.asset is None:
        raise HTTPException(status_code=400, detail="asset_id ve asset zorunludur.")
    target_index: int = find_asset_index_by_id(map_data, asset_id)
    if target_index < 0:
        raise HTTPException(status_code=404, detail="Asset not found")
    existing_asset = ensure_asset_identity(map_data[target_index])
    incoming_asset = ensure_asset_identity({**request.asset, "asset_id": asset_id})
    if str(request.merge_policy or "latest_timestamp_wins") == "latest_timestamp_wins":
        map_data[target_index] = merge_by_latest_timestamp(existing_asset, incoming_asset)
    else:
        map_data[target_index] = incoming_asset
    user_state["map"] = map_data
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return {"status": "updated", "asset": map_data[target_index]}


@app.post("/api/v1/gis/delete-asset-by-id")
def delete_asset_by_id(
    request: AssetMutationRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    asset_id: str = str(request.asset_id or "").strip()
    if asset_id == "":
        raise HTTPException(status_code=400, detail="asset_id zorunludur.")
    target_index: int = find_asset_index_by_id(map_data, asset_id)
    if target_index < 0:
        raise HTTPException(status_code=404, detail="Asset not found")
    removed_asset = map_data.pop(target_index)
    user_state["map"] = map_data
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return {"status": "deleted", "asset": removed_asset}

@app.post("/api/v1/gis/sync")
def sync_gis(
    request: SyncRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_id: str = str(current_user["id"])
    user_state: Dict[str, Any] = get_user_state(user_id)
    server_version: int = int(user_state.get("version", 0))
    if (
        request.base_version is not None
        and request.base_version != server_version
        and len(request.ops) > 0
    ):
        return {
            "status": "conflict",
            "reason": "version_mismatch",
            "map": user_state.get("map", []),
            "version": server_version,
            "updated_at": user_state.get("updated_at"),
        }
    map_data: List[Dict[str, Any]] = canonicalize_map_items(list(user_state.get("map", [])))
    processed_ops: List[str] = list(user_state.get("processed_op_ids", []))
    processed_set = set(processed_ops)
    applied_count: int = 0
    skipped_count: int = 0
    conflicts: List[Dict[str, Any]] = []
    for op in request.ops:
        op_id: str = str(op.client_op_id).strip()
        if op_id == "" or op_id in processed_set:
            skipped_count += 1
            continue
        payload: Dict[str, Any] = dict(op.payload or {})
        op_type: str = str(op.type)
        if op_type == "add_asset":
            asset_obj: Any = payload.get("asset")
            if isinstance(asset_obj, dict):
                map_data.append(ensure_asset_identity(asset_obj))
                applied_count += 1
        elif op_type == "update_asset":
            asset_obj = payload.get("asset")
            target_index: int = _find_asset_index(map_data, payload)
            if isinstance(asset_obj, dict) and 0 <= target_index < len(map_data):
                existing_asset = ensure_asset_identity(map_data[target_index])
                incoming_asset = ensure_asset_identity(asset_obj)
                resolved_asset = merge_by_latest_timestamp(existing_asset, incoming_asset)
                map_data[target_index] = resolved_asset
                applied_count += 1
            else:
                conflicts.append(
                    {
                        "type": "update_asset_not_found",
                        "client_op_id": op_id,
                        "asset_id": payload.get("asset_id"),
                        "index": payload.get("index"),
                    }
                )
        elif op_type == "delete_asset":
            target_index = _find_asset_index(map_data, payload)
            if 0 <= target_index < len(map_data):
                map_data.pop(target_index)
                applied_count += 1
            else:
                conflicts.append(
                    {
                        "type": "delete_asset_not_found",
                        "client_op_id": op_id,
                        "asset_id": payload.get("asset_id"),
                        "index": payload.get("index"),
                    }
                )
        elif op_type == "upload_parcel":
            features: Any = payload.get("features", [])
            if isinstance(features, list) and len(features) > 0:
                for feature in features:
                    if isinstance(feature, dict):
                        map_data.append(ensure_asset_identity(feature))
                applied_count += 1
        elif op_type == "replace_snapshot":
            full_map: Any = payload.get("map")
            if isinstance(full_map, list):
                map_data = canonicalize_map_items([item for item in full_map if isinstance(item, dict)])
                applied_count += 1
        processed_set.add(op_id)
    if applied_count > 0:
        user_state["map"] = map_data
        _touch_user_state(user_state)
    user_state["processed_op_ids"] = list(processed_set)[-500:]
    save_user_state(user_id, user_state)
    return {
        "status": "ok",
        "applied": applied_count,
        "skipped": skipped_count,
        "map": canonicalize_map_items(user_state.get("map", [])),
        "version": user_state.get("version", 0),
        "updated_at": user_state.get("updated_at"),
        "conflicts": conflicts,
        "sync_requested_at": request.sync_requested_at or iso_now_utc(),
    }


@app.post("/api/v1/field/ingest")
def ingest_field_data(
    request: FieldIngestRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    staged_items: List[Dict[str, Any]] = []
    for feature in request.features:
        if not isinstance(feature, dict):
            continue
        feature_copy: Dict[str, Any] = dict(feature)
        feature_props: Dict[str, Any] = dict(feature_copy.get("properties", {}))
        feature_props["ingest_source"] = "field_feature"
        feature_props["ingested_at"] = iso_now_utc()
        if len(request.tkgm_context) > 0:
            feature_props["tkgm_context"] = dict(request.tkgm_context)
        feature_copy["properties"] = feature_props
        staged_items.append(feature_copy)
    for raw_point in request.gps_points:
        if not isinstance(raw_point, dict):
            continue
        try:
            latitude = float(raw_point.get("lat"))
            longitude = float(raw_point.get("lng"))
        except Exception:
            continue
        staged_items.append(
            {
                "name": str(raw_point.get("name") or "Saha Noktası"),
                "type": "Point",
                "geometry": {"type": "Point", "coordinates": [longitude, latitude]},
                "style": {"color": "#03A9F4", "icon": "gps_fixed"},
                "properties": {
                    "iot_connected": False,
                    "ingest_source": "gps_capture",
                    "captured_at": str(raw_point.get("captured_at") or iso_now_utc()),
                    "accuracy_m": raw_point.get("accuracy_m"),
                    "operator": raw_point.get("operator"),
                    "tkgm_context": dict(request.tkgm_context),
                },
            }
        )
    if len(staged_items) == 0:
        return _with_meta(
            {"status": "ok", "ingested": 0, "map": canonicalize_map_items(map_data)},
            current_user,
        )
    map_data.extend(canonicalize_map_items(staged_items))
    user_state["map"] = map_data
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return _with_meta(
        {
            "status": "ok",
            "ingested": len(staged_items),
            "map": canonicalize_map_items(map_data),
            "version": user_state.get("version", 0),
            "updated_at": user_state.get("updated_at"),
        },
        current_user,
    )


@app.get("/api/v1/work-orders")
def list_work_orders(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    work_orders: List[Dict[str, Any]] = list(user_state.get("work_orders", []))
    return _with_meta(
        {"status": "ok", "items": work_orders, "count": len(work_orders)},
        current_user,
    )


@app.post("/api/v1/work-orders")
def create_work_order(
    request: WorkOrderCreateRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    work_orders: List[Dict[str, Any]] = list(user_state.get("work_orders", []))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    payload: Dict[str, Any] = {
        "asset_id": request.asset_id,
        "title": request.title,
        "description": request.description or "",
        "assignee": request.assignee or "",
        "due_at": request.due_at,
        "priority": request.priority or "normal",
        "status": "open",
    }
    created = append_work_order(work_orders, payload)
    target_index = find_asset_index_by_id(map_data, request.asset_id)
    if 0 <= target_index < len(map_data):
        target_asset = ensure_asset_identity(map_data[target_index])
        props: Dict[str, Any] = dict(target_asset.get("properties", {}))
        audit: List[Any] = list(props.get("audit_log", []))
        audit.append(
            {
                "at": iso_now_utc(),
                "event": "work_order_created",
                "work_order_id": created.get("work_order_id"),
            }
        )
        props["audit_log"] = audit[-200:]
        target_asset["properties"] = props
        map_data[target_index] = target_asset
        user_state["map"] = map_data
    user_state["work_orders"] = work_orders
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return _with_meta({"status": "ok", "item": created}, current_user)


@app.patch("/api/v1/work-orders/{work_order_id}")
def patch_work_order(
    work_order_id: str,
    request: WorkOrderUpdateRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    work_orders: List[Dict[str, Any]] = list(user_state.get("work_orders", []))
    patch_data: Dict[str, Any] = {}
    if request.status is not None:
        patch_data["status"] = request.status
    if request.assignee is not None:
        patch_data["assignee"] = request.assignee
    if request.note is not None:
        patch_data["note"] = request.note
    try:
        updated = update_work_order(work_orders, work_order_id, patch_data)
    except ValueError:
        _api_error(
            status_code=404,
            error_code="work_order_not_found",
            message="Guncellenecek is emri bulunamadi.",
            details={"work_order_id": work_order_id},
        )
    user_state["work_orders"] = work_orders
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return _with_meta({"status": "ok", "item": updated}, current_user)


@app.post("/api/v1/iot/telemetry")
async def ingest_telemetry(
    request: TelemetryIngestRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
    telemetry_log: List[Dict[str, Any]] = list(user_state.get("telemetry_log", []))
    alerts: List[Dict[str, Any]] = list(user_state.get("alerts", []))
    normalized = normalize_telemetry(request.dict())
    if normalized.get("asset_id", "") == "":
        _api_error(
            status_code=400,
            error_code="validation_error",
            message="asset_id zorunludur.",
            details={"field": "asset_id"},
        )
    target_index = find_asset_index_by_id(map_data, str(normalized["asset_id"]))
    if target_index < 0:
        _api_error(
            status_code=404,
            error_code="asset_not_found",
            message="Telemetri gonderilecek varlik bulunamadi.",
            details={"asset_id": normalized.get("asset_id")},
        )
    target_asset = ensure_asset_identity(map_data[target_index])
    props: Dict[str, Any] = dict(target_asset.get("properties", {}))
    digital_card: Dict[str, Any] = dict(props.get("digital_card", {}))
    iot_card: Dict[str, Any] = dict(digital_card.get("iot", {}))
    alarm_card: Dict[str, Any] = dict(digital_card.get("alarm", {}))
    metrics: Dict[str, Any] = dict(normalized.get("metrics", {}))
    for key, value in metrics.items():
        iot_card[key] = value
    iot_card["last_seen_at"] = str(normalized.get("measured_at"))
    iot_card["updated_at"] = iso_now_utc()
    digital_card["iot"] = iot_card
    props["digital_card"] = digital_card
    detected_alerts = detect_alerts(iot_card, alarm_card)
    if len(detected_alerts) > 0:
        for alert in detected_alerts:
            alert["asset_id"] = normalized["asset_id"]
            alert["device_id"] = normalized["device_id"]
        alerts.extend(detected_alerts)
        alerts = alerts[-1000:]
    props["iot_connected"] = True
    target_asset["properties"] = props
    map_data[target_index] = ensure_asset_identity(target_asset)
    telemetry_log.append(normalized)
    telemetry_log = telemetry_log[-5000:]
    user_state["map"] = map_data
    user_state["telemetry_log"] = telemetry_log
    user_state["alerts"] = alerts
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    await _broadcast_live_event(
        {
            "type": "telemetry",
            "asset_id": normalized["asset_id"],
            "device_id": normalized["device_id"],
            "metrics": metrics,
            "measured_at": normalized["measured_at"],
            "alerts": detected_alerts,
        }
    )
    return _with_meta(
        {"status": "ok", "telemetry": normalized, "alerts": detected_alerts},
        current_user,
    )


@app.get("/api/v1/iot/alerts")
def list_alerts(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    alerts: List[Dict[str, Any]] = list(user_state.get("alerts", []))
    return _with_meta(
        {"status": "ok", "items": alerts, "count": len(alerts)},
        current_user,
    )


@app.websocket("/ws/live")
async def websocket_live(websocket: WebSocket):
    await websocket.accept()
    live_websocket_clients.append(websocket)
    try:
        await websocket.send_json({"type": "connected", "at": iso_now_utc()})
        while True:
            try:
                incoming = await websocket.receive_json()
                if isinstance(incoming, dict) and str(incoming.get("type")) == "ping":
                    await websocket.send_json({"type": "pong", "at": iso_now_utc()})
            except Exception:
                await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        if websocket in live_websocket_clients:
            live_websocket_clients.remove(websocket)


@app.get("/api/v1/analytics/kpi")
def analytics_kpi(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    kpi = build_kpi(
        map_items=canonicalize_map_items(list(user_state.get("map", []))),
        work_orders=list(user_state.get("work_orders", [])),
        telemetry_log=list(user_state.get("telemetry_log", [])),
        alerts=list(user_state.get("alerts", [])),
    )
    return _with_meta({"status": "ok", "kpi": kpi, "at": iso_now_utc()}, current_user)


@app.post("/api/v1/integrations/erp/sync")
def erp_sync(
    request: ErpSyncRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    job_result = run_connector_sync(
        connector=request.connector,
        payload={
            "assets": canonicalize_map_items(list(user_state.get("map", []))),
            "work_orders": list(user_state.get("work_orders", [])),
            "telemetry": list(user_state.get("telemetry_log", [])),
        },
    )
    jobs: List[Dict[str, Any]] = list(user_state.get("integration_jobs", []))
    jobs.append(job_result)
    user_state["integration_jobs"] = jobs[-200:]
    _touch_user_state(user_state)
    save_user_state(str(current_user["id"]), user_state)
    return _with_meta({"status": "ok", "job": job_result}, current_user)


@app.get("/api/v1/integrations/erp/jobs")
def erp_jobs(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
    jobs: List[Dict[str, Any]] = list(user_state.get("integration_jobs", []))
    return _with_meta(
        {"status": "ok", "items": jobs, "count": len(jobs)},
        current_user,
    )


@app.post("/api/v1/gis/fetch-satellite-image")
def fetch_satellite_image(
    request: AnalysisRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    try:
        if len(request.parcel_geometries) == 0:
            raise HTTPException(status_code=400, detail="Parsel geometrisi bos olamaz.")
        image_rgba_np, minx, miny, maxx, maxy, _, _, used_provider, used_provider_freshness_ts = fetch_masked_satellite_image(parcel_geometries=request.parcel_geometries)
        south_latlon: List[float] = meters_to_latlon(x_meters=minx, y_meters=miny)
        north_latlon: List[float] = meters_to_latlon(x_meters=maxx, y_meters=maxy)
        png_buffer: BytesIO = BytesIO()
        Image.fromarray(image_rgba_np, mode="RGBA").save(png_buffer, format="PNG", optimize=True)
        encoded_image: str = base64.b64encode(png_buffer.getvalue()).decode("utf-8")
        return {
            "status": "success",
            "image_base64": encoded_image,
            "overlay_bounds": {
                "south": south_latlon[0],
                "west": south_latlon[1],
                "north": north_latlon[0],
                "east": north_latlon[1],
            },
            "imagery_provider": used_provider,
            "imagery_provider_freshness_ts": used_provider_freshness_ts,
            "imagery_provider_freshness_status": "known" if used_provider_freshness_ts is not None else "unknown",
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"UYDU GORSELI HATASI: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- 🔥 DERİN ÖĞRENME ANALİZİ 🔥 ---
@app.post("/api/v1/gis/analyze-satellite")
def analyze_satellite(
    request: AnalysisRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    try:
        if len(request.parcel_geometries) == 0:
            raise HTTPException(status_code=400, detail="Parsel geometrisi bos olamaz.")
        print("--- BASIT GORUNTU ANALIZI BASLIYOR ---")
        polygons = [shape(geo) for geo in request.parcel_geometries]
        merged_area = unary_union(polygons)
        image_rgba_np, minx, miny, maxx, maxy, width, height, _, _ = fetch_masked_satellite_image(parcel_geometries=request.parcel_geometries)
        detect_image_rgba: np.ndarray = image_rgba_np
        detect_width: int = width
        detect_height: int = height
        if max(width, height) < 1400:
            upscale_ratio: float = 2.0
            detect_width = int(round(width * upscale_ratio))
            detect_height = int(round(height * upscale_ratio))
            detect_image_rgba = cv2.resize(
                image_rgba_np,
                (detect_width, detect_height),
                interpolation=cv2.INTER_CUBIC,
            )
        detected_assets: List[Dict[str, Any]] = []

        tree_candidates: List[Tuple[float, float]] = []
        if tree_model is not None:
            try:
                print(">> Agaclar DeepForest ile aranıyor...")
                temp_path: str = "temp_sat.jpg"
                Image.fromarray(image_rgba_np, mode="RGBA").convert("RGB").save(temp_path)
                boxes = tree_model.predict_image(path=temp_path, return_plot=False)
                if boxes is not None:
                    for _, row in boxes.iterrows():
                        if row["score"] <= 0.25:
                            continue
                        c_x: float = float((row["xmin"] + row["xmax"]) / 2)
                        c_y: float = float((row["ymin"] + row["ymax"]) / 2)
                        tree_candidates.append((c_x, c_y))
                if os.path.exists(temp_path):
                    os.remove(temp_path)
            except Exception as model_error:
                print(f"DeepForest devre disi, basit algoritmaya geciliyor: {model_error}")
        if len(tree_candidates) == 0:
            print(">> Agaclar basit renk segmentasyonu ile aranıyor...")
            tree_candidates = detect_simple_tree_candidates(image_rgba_np=detect_image_rgba)

        print(">> Yapilar basit sekil analizi ile aranıyor...")
        building_candidates: List[List[Tuple[float, float]]] = detect_simple_structure_candidates(image_rgba_np=detect_image_rgba)

        max_tree_count: int = 800
        if len(tree_candidates) > max_tree_count:
            tree_candidates = tree_candidates[:max_tree_count]

        for c_x, c_y in tree_candidates:
            x_meters: float = minx + (c_x / detect_width) * (maxx - minx)
            y_meters: float = maxy - (c_y / detect_height) * (maxy - miny)
            latlon_coordinates: List[float] = meters_to_latlon(x_meters=x_meters, y_meters=y_meters)
            lat: float = latlon_coordinates[0]
            lng: float = latlon_coordinates[1]
            if merged_area.contains(Point(lng, lat)):
                detected_assets.append({
                    "name": "Ağaç (Ön Analiz)",
                    "type": "Point",
                    "geometry": {"type": "Point", "coordinates": [lng, lat]},
                    "style": {"color": "#4CAF50", "icon": "detected_tree"},
                    "properties": {"iot_connected": False, "status": "unverified", "ai_guess": "agac", "detector": "simple_cv", "asset_type": "agac_nokta"},
                })

        for polygon_pixels in building_candidates:
            latlon_ring: List[List[float]] = []
            for c_x, c_y in polygon_pixels:
                x_meters = minx + (c_x / detect_width) * (maxx - minx)
                y_meters = maxy - (c_y / detect_height) * (maxy - miny)
                latlon_coordinates = meters_to_latlon(x_meters=x_meters, y_meters=y_meters)
                latlon_ring.append([latlon_coordinates[1], latlon_coordinates[0]])
            if len(latlon_ring) < 3:
                continue
            first_point: List[float] = latlon_ring[0]
            last_point: List[float] = latlon_ring[-1]
            if first_point[0] != last_point[0] or first_point[1] != last_point[1]:
                latlon_ring.append([first_point[0], first_point[1]])
            polygon_shape = shape({"type": "Polygon", "coordinates": [latlon_ring]})
            if merged_area.intersects(polygon_shape):
                detected_assets.append({
                    "name": "Yapı (Ön Analiz)",
                    "type": "Polygon",
                    "geometry": {"type": "Polygon", "coordinates": [latlon_ring]},
                    "style": {"color": "#8D6E63", "icon": "detected_building_shape"},
                    "properties": {"iot_connected": False, "status": "unverified", "ai_guess": "yapi", "detector": "simple_cv", "asset_type": "yapi_polygon"},
                })

        user_state: Dict[str, Any] = get_user_state(str(current_user["id"]))
        map_data: List[Dict[str, Any]] = list(user_state.get("map", []))
        map_data.extend(canonicalize_map_items(detected_assets))
        user_state["map"] = map_data
        _touch_user_state(user_state)
        save_user_state(str(current_user["id"]), user_state)

        print(f"Toplam {len(detected_assets)} varlık bulundu.")
        return {"status": "success", "assets": detected_assets}
        
    except Exception as e:
        print(f"HATA: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/admin/farms")
def admin_farms(_: Dict[str, Any] = Depends(require_admin)):
    users_db: Dict[str, Any] = load_users_db()
    users_by_id: Dict[str, Dict[str, Any]] = {
        str(user.get("id")): user for user in users_db.get("users", [])
    }
    state_db: Dict[str, Any] = load_db()
    users_bucket: Dict[str, Any] = state_db.get("users", {})
    farms: List[Dict[str, Any]] = []
    for user_id, state in users_bucket.items():
        if not isinstance(state, dict):
            continue
        map_data: List[Any] = state.get("map", [])
        parcel_count: int = 0
        asset_count: int = 0
        for item in map_data:
            if not isinstance(item, dict):
                continue
            geometry_obj: Any = item.get("geometry", {})
            geometry_type: str = str(geometry_obj.get("type", ""))
            is_asset_polygon: bool = str(item.get("properties", {}).get("asset_type", "")) == "yapi_polygon"
            if geometry_type in ["Polygon", "MultiPolygon"]:
                if is_asset_polygon:
                    asset_count += 1
                else:
                    parcel_count += 1
            elif geometry_type == "Point":
                asset_count += 1
        user_obj: Dict[str, Any] = users_by_id.get(str(user_id), {})
        farms.append(
            {
                "user_id": user_id,
                "email": user_obj.get("email", "unknown"),
                "username": user_obj.get("username", "unknown"),
                "role": user_obj.get("role", "user"),
                "parcel_count": parcel_count,
                "asset_count": asset_count,
                "version": state.get("version", 0),
                "updated_at": state.get("updated_at"),
            }
        )
    return {"farms": farms, "count": len(farms)}
