from fastapi import APIRouter, UploadFile, File, HTTPException
from services.gis_service import GisService
import os
import shutil

router = APIRouter()
gis_service = GisService()

@router.post("/upload-map")
async def upload_map_file(file: UploadFile = File(...)):
    """
    Harita dosyası yükleme noktası.
    Desteklenenler: .geojson, .kml, .shp (zip), .gpkg
    """
    # Geçici dosya yolu
    upload_dir = "temp_uploads"
    os.makedirs(upload_dir, exist_ok=True)
    temp_path = f"{upload_dir}/{file.filename}"
    
    try:
        result = await gis_service.process_upload(file, temp_path)
        if "error" in result:
             raise HTTPException(status_code=400, detail=result["error"])
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
