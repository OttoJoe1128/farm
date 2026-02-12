from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Tuple
import json
import os
import math
import base64
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
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_FILE = "digital_twin_db.json"
MAPBOX_ACCESS_TOKEN = os.getenv("MAPBOX_ACCESS_TOKEN", "")
MAX_IMAGE_DIMENSION = 1024
ESRI_EXPORT_URL = "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export"
REQUEST_TIMEOUT_SECONDS = 90
MIN_BBOX_PADDING_METERS = 2.0
MIN_IMAGE_DIMENSION = 128
TARGET_METERS_PER_PIXEL = 0.6

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

def fetch_masked_satellite_image(parcel_geometries: List[Dict[str, Any]]) -> Tuple[np.ndarray, float, float, float, float, int, int]:
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
    response = None
    last_error_detail: str = "Esri World Imagery hatasi."
    for image_format in ["png32", "png"]:
        query_params: Dict[str, Any] = {
            "bbox": f"{minx},{miny},{maxx},{maxy}",
            "bboxSR": 3857,
            "imageSR": 3857,
            "size": f"{width},{height}",
            "format": image_format,
            "transparent": "true",
            "f": "image",
        }
        try:
            response = requests.get(ESRI_EXPORT_URL, params=query_params, timeout=REQUEST_TIMEOUT_SECONDS)
            if response.status_code == 200:
                break
            body_preview: str = response.text[:300].replace("\n", " ")
            last_error_detail = f"Esri hata status={response.status_code}, format={image_format}, body={body_preview}"
            print(last_error_detail)
        except Exception as e:
            last_error_detail = f"Esri istek hatasi format={image_format}, hata={str(e)}"
            print(last_error_detail)
    if response is None or response.status_code != 200:
        raise HTTPException(status_code=502, detail=last_error_detail)
    image_bytes = BytesIO(response.content)
    image_pil_rgba = Image.open(image_bytes).convert("RGBA")
    alpha_mask = build_parcel_alpha_mask(
        parcel_geometries=projected_geometries,
        image_width=width,
        image_height=height,
        min_x=minx,
        min_y=miny,
        max_x=maxx,
        max_y=maxy,
    )
    image_rgba_np = np.array(image_pil_rgba)
    image_rgba_np[:, :, 3] = alpha_mask
    log_mask_integrity(masked_image_rgba=image_rgba_np, alpha_mask=alpha_mask)
    return image_rgba_np, minx, miny, maxx, maxy, width, height

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
        image_rgba_np, minx, miny, maxx, maxy, _, _ = fetch_masked_satellite_image(parcel_geometries=request.parcel_geometries)
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
        image_rgba_np, minx, miny, maxx, maxy, width, height = fetch_masked_satellite_image(parcel_geometries=request.parcel_geometries)
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
