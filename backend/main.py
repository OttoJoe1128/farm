from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Tuple, Optional
import json
import os
import math
import base64
import datetime
import requests
import cv2
import numpy as np
from io import BytesIO
from PIL import Image
from shapely.geometry import shape, Point
from shapely.ops import unary_union
try:
    from deepforest import main as deepforest_main
except ImportError:
    deepforest_main = None

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:8080",
        "http://localhost:8080",
        "https://127.0.0.1:8080",
        "https://localhost:8080",
    ],
    allow_origin_regex=r"^https://(8000|8080)-.*\.cloudworkstations\.dev$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_FILE = "digital_twin_db.json"
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

def load_db():
    if not os.path.exists(DB_FILE): return []
    with open(DB_FILE, "r") as f: return json.load(f)

def save_db(data):
    with open(DB_FILE, "w") as f: json.dump(data, f)

@app.get("/api/v1/gis/map")
def get_map(): return load_db()

@app.delete("/api/v1/gis/reset-map")
def reset_map():
    save_db([])
    return {"status": "cleared"}

@app.post("/api/v1/gis/upload-map")
async def upload_map(file: UploadFile = File(...)):
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
        current_db = load_db()
        current_db.extend(data)
        save_db(current_db)
        return {"status": "success", "data": data}
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

@app.post("/api/v1/gis/add-asset")
def add_asset(asset: Asset):
    db = load_db()
    db.append(asset.dict())
    save_db(db)
    return {"status": "success"}

@app.put("/api/v1/gis/update-asset/{index}")
def update_asset(index: int, asset: Asset):
    db = load_db()
    if index < 0 or index >= len(db): raise HTTPException(status_code=404, detail="Asset not found")
    db[index] = asset.dict()
    save_db(db)
    return {"status": "updated"}

@app.delete("/api/v1/gis/delete-asset/{index}")
def delete_asset(index: int):
    db = load_db()
    if index < 0 or index >= len(db): raise HTTPException(status_code=404, detail="Asset not found")
    db.pop(index)
    save_db(db)
    return {"status": "deleted"}

@app.post("/api/v1/gis/fetch-satellite-image")
def fetch_satellite_image(request: AnalysisRequest):
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
def analyze_satellite(request: AnalysisRequest):
    try:
        if tree_model is None:
            raise HTTPException(status_code=503, detail="DeepForest kullanima hazir degil.")
        print("--- AI TARAMASI BAŞLIYOR ---")
        polygons = [shape(geo) for geo in request.parcel_geometries]
        merged_area = unary_union(polygons)
        image_rgba_np, minx, miny, maxx, maxy, width, height, _, _ = fetch_masked_satellite_image(parcel_geometries=request.parcel_geometries)
        image_pil = Image.fromarray(image_rgba_np, mode="RGBA").convert("RGB")
        img_np = np.array(image_pil)
        
        detected_assets = []

        # --- AĞAÇ ANALİZİ (DEEPFOREST) ---
        print(">> Ağaçlar Aranıyor...")
        temp_path = "temp_sat.jpg"
        image_pil.save(temp_path)
        
        boxes = tree_model.predict_image(path=temp_path, return_plot=False)
        
        if boxes is not None:
            for index, row in boxes.iterrows():
                if row["score"] > 0.25: # Güven eşiği
                    cX = (row["xmin"] + row["xmax"]) / 2
                    cY = (row["ymin"] + row["ymax"]) / 2
                    x_meters = minx + (cX / width) * (maxx - minx)
                    y_meters = maxy - (cY / height) * (maxy - miny)
                    latlon_coordinates: List[float] = meters_to_latlon(x_meters=x_meters, y_meters=y_meters)
                    lat = latlon_coordinates[0]
                    lng = latlon_coordinates[1]
                    p = Point(lng, lat)
                    if merged_area.contains(p):
                        detected_assets.append({
                            "name": f"Ağaç (%{int(row['score']*100)})",
                            "type": "Point",
                            "geometry": {"type": "Point", "coordinates": [lng, lat]},
                            "style": {"color": "#4CAF50", "icon": "detected_tree"},
                            "properties": {"iot_connected": False, "status": "unverified", "ai_guess": "agac"}
                        })

        # --- YAPI ANALİZİ (GEOMETRİK) ---
        print(">> Yapılar Aranıyor...")
        img_cv = cv2.cvtColor(img_np, cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)
        blurred = cv2.bilateralFilter(gray, 11, 17, 17)
        edged = cv2.Canny(blurred, 30, 200)
        contours, _ = cv2.findContours(edged, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if 300 < area < 8000:
                peri = cv2.arcLength(cnt, True)
                approx = cv2.approxPolyDP(cnt, 0.04 * peri, True)
                if 4 <= len(approx) <= 6:
                    M = cv2.moments(cnt)
                    if M["m00"] != 0:
                        cX = int(M["m10"] / M["m00"])
                        cY = int(M["m01"] / M["m00"])
                        x_meters = minx + (cX / width) * (maxx - minx)
                        y_meters = maxy - (cY / height) * (maxy - miny)
                        latlon_coordinates = meters_to_latlon(x_meters=x_meters, y_meters=y_meters)
                        lat = latlon_coordinates[0]
                        lng = latlon_coordinates[1]
                        p = Point(lng, lat)
                        if merged_area.contains(p):
                            detected_assets.append({
                                "name": "Yapı",
                                "type": "Point",
                                "geometry": {"type": "Point", "coordinates": [lng, lat]},
                                "style": {"color": "#8D6E63", "icon": "detected_building"},
                                "properties": {"iot_connected": False, "status": "unverified", "ai_guess": "yapi"}
                            })

        db = load_db()
        db.extend(detected_assets)
        save_db(db)
        
        if os.path.exists(temp_path): os.remove(temp_path)
        print(f"Toplam {len(detected_assets)} varlık bulundu.")
        return {"status": "success", "assets": detected_assets}
        
    except Exception as e:
        print(f"HATA: {e}")
        raise HTTPException(status_code=500, detail=str(e))
