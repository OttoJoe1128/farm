from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any
import json
import os
import requests
import cv2
import numpy as np
from io import BytesIO
from PIL import Image
from shapely.geometry import shape, Point
from shapely.ops import unary_union
# --- YENİ ZEKAMIZ ---
from deepforest import main as deepforest_main

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_FILE = "digital_twin_db.json"
MAPBOX_ACCESS_TOKEN = "pk.eyJ1IjoiZHJhZ29zbGlzcyIsImEiOiJjbWV3dDhudDUwczByMm1zaHhjNmo3bTQxIn0.slZRFqawbHmuAphq621qAw"

# --- MODELİ YÜKLE ---
print("Yapay Zeka Modeli (DeepForest) Hazırlanıyor...")
tree_model = deepforest_main.deepforest()
tree_model.use_release() # Hazır eğitilmiş model
print("✅ MODEL HAZIR!")

class Asset(BaseModel):
    name: str
    type: str
    geometry: Dict[str, Any]
    style: Dict[str, Any]
    properties: Dict[str, Any]

class AnalysisRequest(BaseModel):
    parcel_geometries: List[Dict[str, Any]]

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
def upload_map(data: List[Dict[str, Any]]):
    current_db = load_db()
    current_db.extend(data)
    save_db(current_db)
    return {"status": "success"}

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

# --- 🔥 DERİN ÖĞRENME ANALİZİ 🔥 ---
@app.post("/api/v1/gis/analyze-satellite")
def analyze_satellite(request: AnalysisRequest):
    try:
        print("--- AI TARAMASI BAŞLIYOR ---")
        
        # 1. Alanı Birleştir
        polygons = [shape(geo) for geo in request.parcel_geometries]
        merged_area = unary_union(polygons)
        minx, miny, maxx, maxy = merged_area.bounds
        
        width, height = 1500, 1500
        bbox_str = f"{minx},{miny},{maxx},{maxy}"
        url = f"https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/[{bbox_str}]/{width}x{height}?access_token={MAPBOX_ACCESS_TOKEN}"
        
        response = requests.get(url)
        if response.status_code != 200:
            return {"status": "error", "message": "Mapbox hatası."}

        image_bytes = BytesIO(response.content)
        image_pil = Image.open(image_bytes).convert("RGB")
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
                    
                    lng = minx + (cX / width) * (maxx - minx)
                    lat = maxy - (cY / height) * (maxy - miny)
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
                        lng = minx + (cX / width) * (maxx - minx)
                        lat = maxy - (cY / height) * (maxy - miny)
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
