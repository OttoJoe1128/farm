import geopandas as gpd
import json
import os
from shapely.geometry import shape, mapping
from fastapi import UploadFile

class GisService:
    async def process_upload(self, file: UploadFile, temp_path: str):
        print(f"--- ANALİZ BAŞLIYOR: {file.filename} ---")
        
        with open(temp_path, "wb") as f:
            f.write(await file.read())

        try:
            gdf = gpd.read_file(temp_path)
        except Exception as e:
            return {"error": f"Dosya okunamadı: {str(e)}"}

        # 1. GPS Koordinatlarına (WGS84) Çevir
        if gdf.crs != "EPSG:4326":
            gdf = gdf.to_crs("EPSG:4326")

        # 2. Alan Hesabı İçin Metrik Sisteme Çevir (Metrekare hesabı için şart)
        try:
            gdf_meters = gdf.to_crs(epsg=3857)
        except:
            # Eğer projeksiyon hatası verirse tahmini hesapla
            gdf_meters = gdf 

        digital_twin_objects = []

        # --- DÖNGÜ: Dosyadaki HER BİR ŞEKLİ tek tek inceliyoruz ---
        for index, row in gdf.iterrows():
            try:
                geom = row.geometry # Şekil (Koordinatlar)
                
                # Alanı hesapla (Metrekare cinsinden)
                area_sqm = 0
                if geom.geom_type in ['Polygon', 'MultiPolygon']:
                    area_sqm = gdf_meters.iloc[index].geometry.area
                
                # Dosyadaki verileri al (Varsa isim, numara vs.)
                props = row.drop('geometry').to_dict()
                
                # --- YAPAY ZEKA MANTIĞI BURADA ---
                
                entity_type = "bilinmeyen"
                display_name = props.get('name', f"Varlık #{index+1}")
                color = "#9E9E9E" 
                icon = "help"
                geom_type = geom.geom_type

                # SENARYO 1: NOKTA (Ağaç, Direk, Kuyu)
                if geom_type in ['Point', 'MultiPoint']:
                    # Eğer dosya içinde "tür" belirtilmemişse biz tahmin edelim
                    entity_type = "agac" 
                    display_name = "Ağaç / Bitki"
                    color = "#4CAF50" # Yeşil
                    icon = "park"
                    
                    # Dosyada ipucu varsa kullan
                    p_str = str(props).lower()
                    if "kuyu" in p_str or "su" in p_str: 
                        entity_type = "kuyu"; display_name="Su Kuyusu"; color = "#2196F3"; icon = "water_drop"
                    if "direk" in p_str or "elektrik" in p_str:
                        entity_type = "altyapi"; display_name="Elektrik Direği"; color = "#FFC107"; icon = "bolt"

                # SENARYO 2: ALAN (Tarla mı? Ev mi?)
                elif geom_type in ['Polygon', 'MultiPolygon']:
                    
                    # KURAL: 500 m²'den BÜYÜKSE -> ARAZİDİR
                    if area_sqm > 500: 
                        entity_type = "tarla"
                        display_name = f"Arazi / Parsel ({int(area_sqm)} m²)"
                        color = "#8BC34A" # Açık Yeşil (Tarla Rengi)
                        icon = "landscape"
                    
                    # KURAL: 500 m²'den KÜÇÜKSE -> YAPIDIR (Evin kendisi, ahır, depo)
                    else:
                        entity_type = "yapi"
                        display_name = f"Yapı / Depo ({int(area_sqm)} m²)"
                        color = "#795548" # Kahverengi (Bina Rengi)
                        icon = "home"

                # SENARYO 3: ÇİZGİ (Yol, Boru Hattı)
                elif geom_type in ['LineString', 'MultiLineString']:
                    entity_type = "altyapi"
                    display_name = "Yol / Hat"
                    color = "#607D8B"
                    icon = "timeline"

                # Sonucu Pakettle
                digital_twin_objects.append({
                    "id": str(index),
                    "name": display_name,
                    "type": entity_type,
                    "geometry": json.loads(json.dumps(mapping(geom))),
                    "properties": {**props, "area_sqm": round(area_sqm, 2), "iot_connected": False},
                    "style": {"color": color, "icon": icon}
                })
            except Exception as e:
                print(f"Satır hatası: {e}")

        os.remove(temp_path)
        print(f"--- ANALİZ BİTTİ: {len(digital_twin_objects)} farklı varlık bulundu ---")
        return {"status": "success", "data": digital_twin_objects}
