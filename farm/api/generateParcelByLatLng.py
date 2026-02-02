from flask import Flask, request, jsonify
from flask_cors import CORS
from shapely.geometry import Polygon, Point, LineString
from shapely.ops import transform
import pyproj
import requests
import math
import json
import os
import uuid
import sqlite3
import time
from datetime import datetime
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

# GeoJSONLoader konfigürasyonu
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
ALLOWED_EXTENSIONS = {'geojson', 'json'}

# Upload klasörü oluştur
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# SQLite veritabanı kurulumu
DATABASE_FILE = 'smartfarm_data.db'

def init_database():
    """Veritabanı tablolarını oluştur"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    # Kullanıcılar tablosu
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_token TEXT UNIQUE NOT NULL,
            username TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Çiftlik tasarımları tablosu
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS farm_designs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_token TEXT NOT NULL,
            design_name TEXT NOT NULL,
            design_data TEXT NOT NULL,
            geojson_parcels TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_active BOOLEAN DEFAULT 1
        )
    ''')
    
    # GeoJSON parseller tablosu
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS geojson_parcels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_token TEXT NOT NULL,
            parcel_id TEXT NOT NULL,
            polygon_data TEXT NOT NULL,
            area REAL,
            properties TEXT,
            is_merged BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_token) REFERENCES users (user_token)
        )
    ''')
    
    # Çiftlik tasarımları tablosu
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS farm_designs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_token TEXT NOT NULL,
            parcel_id TEXT NOT NULL,
            design_data TEXT NOT NULL,
            design_type TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_token) REFERENCES users (user_token)
        )
    ''')
    
    conn.commit()
    conn.close()

# Veritabanını başlat
init_database()

parcel_id_counter = 1
geojson_parcels = []  # Geçici cache - veritabanı kullanacağız

def create_polygon(lat, lng, size=0.00005):
    return [
        [lng - size, lat - size],
        [lng + size, lat - size],
        [lng + size, lat + size],
        [lng - size, lat + size]
    ]

def calculate_area(polygon):
    poly = Polygon([(lng, lat) for lng, lat in polygon])
    return poly.area * 1000000  # m²

def get_osm_data(lat, lng, radius=100):
    """OpenStreetMap'ten çevredeki yol, bina, alan bilgilerini al"""
    try:
        # Overpass API sorgusu - yollar, binalar, su alanları
        overpass_url = "http://overpass-api.de/api/interpreter"
        overpass_query = f"""
        [out:json][timeout:25];
        (
          way["highway"](around:{radius},{lat},{lng});
          way["building"](around:{radius},{lat},{lng});
          way["landuse"](around:{radius},{lat},{lng});
          way["natural"="water"](around:{radius},{lat},{lng});
          relation["building"](around:{radius},{lat},{lng});
        );
        out geom;
        """
        
        response = requests.get(overpass_url, params={'data': overpass_query}, timeout=10)
        if response.status_code == 200:
            return response.json()
        return None
    except Exception as e:
        print(f"OSM veri alınamadı: {e}")
        return None

def analyze_area_type(lat, lng):
    """AI: Koordinatın bulunduğu alan tipini analiz et"""
    osm_data = get_osm_data(lat, lng)
    
    print(f"🗺️ OSM veri alındı: {len(osm_data.get('elements', [])) if osm_data else 0} element")
    
    if not osm_data or 'elements' not in osm_data:
        print("⚠️ OSM veri yok, doğal alan varsayılıyor")
        return "natural", 0.0006  # Varsayılan doğal alan
    
    elements = osm_data['elements']
    
    # Yakındaki özellikler
    nearby_highways = []
    nearby_buildings = []
    nearby_landuse = []
    
    for element in elements:
        if 'tags' in element:
            tags = element['tags']
            
            # Yol tipleri
            if 'highway' in tags:
                nearby_highways.append(tags['highway'])
            
            # Bina tipleri  
            if 'building' in tags:
                nearby_buildings.append(tags['building'])
                
            # Arazi kullanımı
            if 'landuse' in tags:
                nearby_landuse.append(tags['landuse'])
    
    # AI Karar Sistemi
    return classify_area_ai(nearby_highways, nearby_buildings, nearby_landuse)

def classify_area_ai(highways, buildings, landuse):
    """Yapay Zeka: Alan tipini sınıflandır ve uygun parsel boyutu öner"""
    
    # Yoğun şehir merkezi
    if any(hw in ['primary', 'secondary', 'trunk'] for hw in highways) and len(buildings) > 5:
        return "urban_center", 0.00002  # Çok küçük (şehir merkezi)
    
    # Yerleşim alanı
    elif any(hw in ['residential', 'living_street'] for hw in highways) or 'residential' in landuse:
        return "residential", 0.00003  # Küçük (konut alanı)
    
    # Ticari alan
    elif 'commercial' in landuse or any(b in ['commercial', 'retail'] for b in buildings):
        return "commercial", 0.00004  # Orta küçük (ticari)
    
    # Sanayi alanı
    elif 'industrial' in landuse or any(b == 'industrial' for b in buildings):
        return "industrial", 0.00008  # Orta büyük (sanayi)
    
    # Tarım alanı
    elif any(lu in ['farmland', 'farm', 'meadow'] for lu in landuse):
        return "farmland", 0.0002   # Büyük (tarım)
    
    # Orman/doğal alan
    elif any(lu in ['forest', 'grass', 'scrub'] for lu in landuse):
        if 'forest' in landuse:
            return "forest", 0.0008    # Çok büyük (orman)
        else:
            return "natural", 0.0006   # Büyük (doğal alan)
    
    # Belirsiz alan - veri yoksa büyük rural parsel (muhtemelen doğal alan)
    else:
        return "natural", 0.0006     # Varsayılan doğal alan boyutu

def find_boundary_features(lat, lng, radius=100):
    """Parsel sınırı için doğal ve yapay engelleri bul - AutoParcelBoundaryRules"""
    try:
        overpass_url = "http://overpass-api.de/api/interpreter"
        overpass_query = f"""
        [out:json][timeout:25];
        (
          way["building"](around:{radius},{lat},{lng});
          way["highway"](around:{radius*2},{lat},{lng});
          way["waterway"~"^(river|stream|ditch|canal)$"](around:{radius*2},{lat},{lng});
          way["natural"~"^(cliff|ridge|tree_row)$"](around:{radius*2},{lat},{lng});
          way["barrier"~"^(fence|wall|hedge)$"](around:{radius},{lat},{lng});
          way["landuse"](around:{radius*2},{lat},{lng});
          way["leisure"~"^(park|garden)$"](around:{radius},{lat},{lng});
        );
        out geom;
        """
        
        response = requests.get(overpass_url, params={'data': overpass_query}, timeout=5)
        if response.status_code != 200:
            return {'buildings': [], 'roads': []}
            
        data = response.json()
        boundaries = {
            'buildings': [],
            'roads': [],
            'waterways': [],
            'natural_barriers': [],
            'artificial_barriers': [],
            'landuse_areas': []
        }
        
        for element in data.get('elements', []):
            if 'geometry' in element and 'tags' in element:
                coords = [(node['lon'], node['lat']) for node in element['geometry']]
                if len(coords) > 1:
                    point = Point(lng, lat)
                    tags = element['tags']
                    
                    # Engel tipini belirle
                    if 'building' in tags:
                        # Bina sınırı
                        if len(coords) > 2:
                            building_polygon = Polygon(coords)
                            distance = point.distance(building_polygon.exterior) * 111000
                            boundaries['buildings'].append({
                                'geometry': coords,
                                'distance': distance,
                                'type': 'building',
                                'polygon': building_polygon,
                                'building_type': tags.get('building', 'unknown')
                            })
                    
                    elif 'highway' in tags:
                        # Yol sınırı
                        road_line = LineString(coords)
                        distance = point.distance(road_line) * 111000
                        boundaries['roads'].append({
                            'geometry': coords,
                            'distance': distance,
                            'type': 'road',
                            'highway': tags.get('highway', 'unknown'),
                            'line': road_line
                        })
                    
                    elif 'waterway' in tags:
                        # Su sınırı (dere, nehir, kanal)
                        water_line = LineString(coords)
                        distance = point.distance(water_line) * 111000
                        boundaries['waterways'].append({
                            'geometry': coords,
                            'distance': distance,
                            'type': 'waterway',
                            'waterway': tags.get('waterway', 'unknown'),
                            'line': water_line
                        })
                    
                    elif 'natural' in tags:
                        # Doğal sınır (kayalık, sırt, ağaç sırası)
                        natural_line = LineString(coords)
                        distance = point.distance(natural_line) * 111000
                        boundaries['natural_barriers'].append({
                            'geometry': coords,
                            'distance': distance,
                            'type': 'natural',
                            'natural': tags.get('natural', 'unknown'),
                            'line': natural_line
                        })
                    
                    elif 'barrier' in tags:
                        # Yapay sınır (çit, duvar, çalı)
                        barrier_line = LineString(coords)
                        distance = point.distance(barrier_line) * 111000
                        boundaries['artificial_barriers'].append({
                            'geometry': coords,
                            'distance': distance,
                            'type': 'barrier',
                            'barrier': tags.get('barrier', 'unknown'),
                            'line': barrier_line
                        })
                    
                    elif 'landuse' in tags:
                        # Arazi kullanım sınırı
                        if len(coords) > 2:
                            landuse_polygon = Polygon(coords)
                            distance = point.distance(landuse_polygon.exterior) * 111000
                            boundaries['landuse_areas'].append({
                                'geometry': coords,
                                'distance': distance,
                                'type': 'landuse',
                                'landuse': tags.get('landuse', 'unknown'),
                                'polygon': landuse_polygon
                            })
        
        # Mesafeye göre sırala
        for key in boundaries:
            boundaries[key] = sorted(boundaries[key], key=lambda x: x['distance'])
        
        return boundaries
    except Exception as e:
        print(f"Sınır verileri alınamadı: {e}")
        return {
            'buildings': [], 'roads': [], 'waterways': [],
            'natural_barriers': [], 'artificial_barriers': [], 'landuse_areas': []
        }

def calculate_block_boundaries(lat, lng, roads):
    """Sokaklar arası blok sınırlarını hesapla"""
    if not roads:
        return None
        
    # Tıklanan noktadan sokak mesafeleri
    point = Point(lng, lat)
    boundaries = {'north': None, 'south': None, 'east': None, 'west': None}
    
    for road in roads:
        road_line = LineString(road['geometry'])
        
        # En yakın nokta
        nearest_point = road_line.interpolate(road_line.project(point))
        
        # Yön belirleme (basit compass logic)
        lat_diff = nearest_point.y - lat
        lng_diff = nearest_point.x - lng
        
        if abs(lat_diff) > abs(lng_diff):  # Kuzey-Güney yolu
            if lat_diff > 0:
                boundaries['north'] = nearest_point.y
            else:
                boundaries['south'] = nearest_point.y
        else:  # Doğu-Batı yolu
            if lng_diff > 0:
                boundaries['east'] = nearest_point.x
            else:
                boundaries['west'] = nearest_point.x
    
    return boundaries

def create_block_polygon(lat, lng, boundaries):
    """Sokaklar arası tam blok polygon oluştur"""
    # Varsayılan mesafeler (eğer sokak bulunamazsa)
    default_distance = 0.001  # ~100m
    
    # Sınırları belirle
    north = boundaries.get('north') or (lat + default_distance)
    south = boundaries.get('south') or (lat - default_distance)
    east = boundaries.get('east') or (lng + default_distance)
    west = boundaries.get('west') or (lng - default_distance)
    
    # Minimum/maksimum boyut kontrolü
    max_size = 0.003  # Max ~300m
    min_size = 0.0005  # Min ~50m
    
    # Boyut kontrolü
    lat_size = abs(north - south)
    lng_size = abs(east - west)
    
    if lat_size > max_size:
        center_lat = (north + south) / 2
        north = center_lat + max_size/2
        south = center_lat - max_size/2
        
    if lng_size > max_size:
        center_lng = (east + west) / 2
        east = center_lng + max_size/2
        west = center_lng - max_size/2
        
    if lat_size < min_size:
        center_lat = (north + south) / 2
        north = center_lat + min_size/2
        south = center_lat - min_size/2
        
    if lng_size < min_size:
        center_lng = (east + west) / 2
        east = center_lng + min_size/2
        west = center_lng - min_size/2
    
    # Kapalı polygon oluştur
    polygon = [
        [west, south],   # Sol alt
        [east, south],   # Sağ alt  
        [east, north],   # Sağ üst
        [west, north],   # Sol üst
        [west, south]    # Kapalı polygon için
    ]
    
    return polygon[:-1]  # Son tekrar eden noktayı çıkar

def create_building_parcel(lat, lng, building_data, roads_data, area_type):
    """Bina bazlı akıllı parsel oluştur - apartman boyutu"""
    # En yakın binayı bul
    if building_data and len(building_data) > 0:
        nearest_building = building_data[0]
        building_polygon = nearest_building['polygon']
        
        # Binanın etrafında küçük buffer ekle (5-10m)
        buffer_size = 0.00005  # ~5m buffer
        bounds = building_polygon.bounds  # (minx, miny, maxx, maxy)
        
        parcel_polygon = [
            [bounds[0] - buffer_size, bounds[1] - buffer_size],  # Sol alt
            [bounds[2] + buffer_size, bounds[1] - buffer_size],  # Sağ alt
            [bounds[2] + buffer_size, bounds[3] + buffer_size],  # Sağ üst
            [bounds[0] - buffer_size, bounds[3] + buffer_size]   # Sol üst
        ]
        
        return parcel_polygon, "building_parcel", "bina_bazli"
    
    # Bina bulunamazsa alan tipine göre karar ver
    elif roads_data and len(roads_data) >= 2:
        # Şehir içi ise küçük apartman, doğal alan ise büyük parsel
        if area_type in ["urban_center", "residential", "commercial"]:
            return create_small_street_parcel(lat, lng, roads_data)
        else:
            # Orman/tarım için büyük parsel
            return create_large_rural_parcel(lat, lng, area_type)
    
    # Hiçbiri yoksa alan tipine göre varsayılan
    else:
        if area_type in ["farmland", "natural", "forest"]:
            return create_large_rural_parcel(lat, lng, area_type)
        else:
            return create_small_default_parcel(lat, lng)

def create_small_street_parcel(lat, lng, roads_data):
    """Sokak bazlı ama küçük apartman boyutunda parsel"""
    point = Point(lng, lat)
    min_distances = {'north': float('inf'), 'south': float('inf'), 
                    'east': float('inf'), 'west': float('inf')}
    
    for road in roads_data:
        road_line = LineString(road['geometry'])
        nearest_point = road_line.interpolate(road_line.project(point))
        
        # Mesafe hesapla
        distance = point.distance(nearest_point) * 111000  # metre
        
        # Yön belirleme
        lat_diff = nearest_point.y - lat
        lng_diff = nearest_point.x - lng
        
        if abs(lat_diff) > abs(lng_diff):  # Kuzey-Güney
            if lat_diff > 0 and distance < min_distances['north']:
                min_distances['north'] = distance
            elif lat_diff < 0 and distance < min_distances['south']:
                min_distances['south'] = distance
        else:  # Doğu-Batı
            if lng_diff > 0 and distance < min_distances['east']:
                min_distances['east'] = distance
            elif lng_diff < 0 and distance < min_distances['west']:
                min_distances['west'] = distance
    
    # Apartman boyutu hesapla (max 30m)
    max_apartment_size = 0.0003  # ~30m
    size_north = min(min_distances['north'] / 111000 * 0.7, max_apartment_size)
    size_south = min(min_distances['south'] / 111000 * 0.7, max_apartment_size)
    size_east = min(min_distances['east'] / 111000 * 0.7, max_apartment_size)
    size_west = min(min_distances['west'] / 111000 * 0.7, max_apartment_size)
    
    # Minimum boyut kontrolü
    min_size = 0.00002  # ~2m minimum
    size_north = max(size_north, min_size)
    size_south = max(size_south, min_size)
    size_east = max(size_east, min_size)
    size_west = max(size_west, min_size)
    
    polygon = [
        [lng - size_west, lat - size_south],    # Sol alt
        [lng + size_east, lat - size_south],    # Sağ alt
        [lng + size_east, lat + size_north],    # Sağ üst
        [lng - size_west, lat + size_north]     # Sol üst
    ]
    
    return polygon, "street_apartment", "sokak_apartman"

def create_small_default_parcel(lat, lng):
    """Varsayılan küçük apartman boyutu"""
    size = 0.00003  # ~3m
    polygon = [
        [lng - size, lat - size],
        [lng + size, lat - size],
        [lng + size, lat + size],
        [lng - size, lat + size]
    ]
    return polygon, "default_apartment", "varsayilan_apartman"

def create_large_rural_parcel(lat, lng, area_type):
    """Büyük tarım/orman parseli oluştur"""
    # Alan tipine göre boyut belirle
    size_map = {
        "farmland": 0.005,    # ~500m (25 hektar / 250 dönüm)
        "natural": 0.008,     # ~800m (64 hektar / 640 dönüm) 
        "forest": 0.008,      # ~800m (64 hektar / 640 dönüm)
        "mixed": 0.003,       # ~300m (9 hektar / 90 dönüm)
        "industrial": 0.004   # ~400m (16 hektar / 160 dönüm)
    }
    
    # 1 dönüm = 1000 m² için boyut hesapla
    # 1000 m² = 31.6m x 31.6m ≈ 0.0003 derece
    donum_size = 0.0003  # 1 dönüm boyutu
    
    # Alan tipine göre dönüm sayısı
    donum_count_map = {
        "farmland": 10,    # 10 dönüm tarla
        "natural": 20,     # 20 dönüm doğal alan
        "forest": 20,      # 20 dönüm orman
        "mixed": 5,        # 5 dönüm karışık
        "industrial": 8    # 8 dönüm sanayi
    }
    
    donum_count = donum_count_map.get(area_type, 1)  # Varsayılan 1 dönüm
    total_size = donum_size * (donum_count ** 0.5)  # Kare kök alarak boyut
    
    # Minimum ve maksimum sınırlar
    total_size = max(total_size, 0.0003)  # Min 1 dönüm
    total_size = min(total_size, 0.01)    # Max 100 hektar
    
    polygon = [
        [lng - total_size, lat - total_size],
        [lng + total_size, lat - total_size], 
        [lng + total_size, lat + total_size],
        [lng - total_size, lat + total_size]
    ]
    
    return polygon, f"{area_type}_rural", f"{donum_count}_donum"

def create_boundary_based_parcel(lat, lng, boundaries):
    """AutoParcelBoundaryRules - Doğal ve yapay engellere göre parsel sınırı oluştur"""
    print(f"🎯 AutoParcelBoundaryRules aktif - Engel analizi başlatılıyor...")
    
    point = Point(lng, lat)
    
    # Tüm engelleri birleştir ve analiz et
    all_barriers = []
    
    # Binalar (güçlü sınır)
    for building in boundaries.get('buildings', [])[:3]:
        all_barriers.append({
            'type': 'building',
            'strength': 10,  # En güçlü sınır
            'geometry': building['geometry'],
            'distance': building['distance']
        })
    
    # Yollar (güçlü sınır)
    for road in boundaries.get('roads', [])[:4]:
        all_barriers.append({
            'type': 'road',
            'strength': 8,
            'geometry': road['geometry'],
            'distance': road['distance']
        })
    
    # Su kanalları (çok güçlü sınır)
    for water in boundaries.get('waterways', [])[:2]:
        all_barriers.append({
            'type': 'waterway',
            'strength': 9,
            'geometry': water['geometry'],
            'distance': water['distance']
        })
    
    # Doğal engeller (orta sınır)
    for natural in boundaries.get('natural_barriers', [])[:2]:
        all_barriers.append({
            'type': 'natural',
            'strength': 6,
            'geometry': natural['geometry'],
            'distance': natural['distance']
        })
    
    # Yapay bariyerler (orta sınır)
    for barrier in boundaries.get('artificial_barriers', [])[:3]:
        all_barriers.append({
            'type': 'barrier',
            'strength': 5,
            'geometry': barrier['geometry'],
            'distance': barrier['distance']
        })
    
    # Engelleri mesafe ve güce göre sırala
    effective_barriers = sorted([b for b in all_barriers if b['distance'] < 50], 
                               key=lambda x: (x['distance'], -x['strength']))[:6]
    
    print(f"🛡️ {len(effective_barriers)} etkili engel bulundu")
    
    if len(effective_barriers) >= 2:
        # Engellere göre polygon oluştur
        return create_polygon_from_barriers(lat, lng, effective_barriers)
    else:
        # Engel yok - minimum 1 dönüm (1000 m²) parsel
        print("🌾 Açık arazi - minimum 1 dönüm parsel oluşturuluyor")
        return create_minimum_area_parcel(lat, lng)

def create_polygon_from_barriers(lat, lng, barriers):
    """Engellere göre gerçekçi polygon oluştur"""
    point = Point(lng, lat)
    
    # 4 yön için sınır noktaları bul
    boundaries = {
        'north': lat + 0.002,   # Varsayılan ~200m
        'south': lat - 0.002,
        'east': lng + 0.002,
        'west': lng - 0.002
    }
    
    # Her engel için en yakın noktayı bul ve sınırları güncelle
    for barrier in barriers:
        coords = barrier['geometry']
        barrier_line = LineString(coords)
        
        # En yakın noktayı bul
        nearest_point = barrier_line.interpolate(barrier_line.project(point))
        
        # Yönü belirle ve sınırı güncelle
        lat_diff = nearest_point.y - lat
        lng_diff = nearest_point.x - lng
        
        # Engel gücüne göre sınır mesafesi ayarla
        strength_factor = barrier['strength'] / 10.0
        
        if abs(lat_diff) > abs(lng_diff):  # Kuzey-Güney engeli
            if lat_diff > 0 and nearest_point.y < boundaries['north']:
                boundaries['north'] = nearest_point.y - 0.00005 * strength_factor
            elif lat_diff < 0 and nearest_point.y > boundaries['south']:
                boundaries['south'] = nearest_point.y + 0.00005 * strength_factor
        else:  # Doğu-Batı engeli
            if lng_diff > 0 and nearest_point.x < boundaries['east']:
                boundaries['east'] = nearest_point.x - 0.00005 * strength_factor
            elif lng_diff < 0 and nearest_point.x > boundaries['west']:
                boundaries['west'] = nearest_point.x + 0.00005 * strength_factor
    
    # Minimum alan kontrolü (1 dönüm = 1000 m² ≈ 0.0003 derece kare)
    min_size = 0.0003 ** 0.5  # √(1 dönüm)
    
    lat_size = boundaries['north'] - boundaries['south']
    lng_size = boundaries['east'] - boundaries['west']
    
    if lat_size < min_size:
        center_lat = (boundaries['north'] + boundaries['south']) / 2
        boundaries['north'] = center_lat + min_size/2
        boundaries['south'] = center_lat - min_size/2
        
    if lng_size < min_size:
        center_lng = (boundaries['east'] + boundaries['west']) / 2
        boundaries['east'] = center_lng + min_size/2
        boundaries['west'] = center_lng - min_size/2
    
    # Polygon oluştur
    polygon = [
        [boundaries['west'], boundaries['south']],   # Sol alt
        [boundaries['east'], boundaries['south']],   # Sağ alt
        [boundaries['east'], boundaries['north']],   # Sağ üst
        [boundaries['west'], boundaries['north']]    # Sol üst
    ]
    
    return polygon, "boundary_adaptive", f"{len(barriers)}_engel"

def create_minimum_area_parcel(lat, lng):
    """Açık arazi için minimum 1 dönüm parsel"""
    # 1 dönüm = 1000 m² = ~31.6m x 31.6m ≈ 0.0003 derece kare
    size = (0.0003 ** 0.5) / 2  # Yarı boyut
    
    polygon = [
        [lng - size, lat - size],   # Sol alt
        [lng + size, lat - size],   # Sağ alt
        [lng + size, lat + size],   # Sağ üst
        [lng - size, lat + size]    # Sol üst
    ]
    
    return polygon, "open_field", "1_donum_minimum"

def create_smart_polygon(lat, lng):
    """AutoParcelBoundaryRules - Akıllı sınır bazlı parsel oluştur"""
    area_type, base_size = analyze_area_type(lat, lng)
    
    print(f"🔍 Alan tipi tespit edildi: {area_type}")
    
    # Sınır verilerini al
    boundaries = find_boundary_features(lat, lng)
    
    # AutoParcelBoundaryRules uygula
    return create_boundary_based_parcel(lat, lng, boundaries)

@app.route('/api/generateParcelByLatLng', methods=['GET', 'OPTIONS'])
def generate_parcel():
    global parcel_id_counter
    lat = request.args.get('lat', type=float)
    lng = request.args.get('lng', type=float)
    if lat is None or lng is None:
        return jsonify({"error": "lat ve lng parametreleri gerekli"}), 400

    # AI ile akıllı parsel oluştur
    try:
        smart_polygon, area_type, smart_size = create_smart_polygon(lat, lng)
        area = calculate_area(smart_polygon)
        
        # AutoParcelBoundaryRules - Parsel tipi belirleme
        parcel_type = determine_parcel_type(area_type, smart_size)
        generation_method = determine_generation_method(smart_size)
        
        parcel = {
            "parcel_id": parcel_id_counter,
            "owner": "Otto Joe",
            "type": parcel_type,
            "area": area,
            "polygon": smart_polygon,
            "boundary_analysis": {
                "area_type": area_type,
                "generation_method": generation_method,
                "boundary_info": smart_size,
                "description": get_area_description(area_type),
                "min_area_met": area >= 1000,  # 1 dönüm kontrolü
                "boundary_count": extract_boundary_count(smart_size)
            }
        }
        parcel_id_counter += 1
        return jsonify(parcel), 200
        
    except Exception as e:
        # AI başarısız olursa varsayılan sisteme dön
        print(f"AI analizi başarısız: {e}")
        polygon = create_polygon(lat, lng)
        area = calculate_area(polygon)
        parcel = {
            "parcel_id": parcel_id_counter,
            "owner": "Otto Joe", 
            "type": "Varsayılan Parsel",
            "area": area,
            "polygon": polygon,
            "ai_analysis": {
                "area_type": "fallback",
                "size_factor": 0.00005,
                "description": "AI analizi başarısız - varsayılan boyut"
            }
        }
        parcel_id_counter += 1
        return jsonify(parcel), 200

def get_area_description(area_type):
    """Alan tipi için açıklama metni"""
    descriptions = {
        "urban_center": "Yoğun şehir merkezi - Çok küçük parsel",
        "residential": "Konut alanı - Apartman boyutu",
        "commercial": "Ticari alan - Orta boyut",
        "industrial": "Sanayi alanı - Büyük boyut", 
        "farmland": "Tarım alanı - Çok büyük parsel",
        "natural": "Doğal alan - En büyük parsel",
        "forest": "Orman alanı - Ağaçlık bölge",
        "mixed": "Karma alan - Standart boyut",
        "unknown": "Bilinmeyen alan - Varsayılan boyut",
        "boundary_adaptive": "Sınır bazlı parsel - doğal/yapay engellere göre",
        "open_field": "Açık arazi - minimum 1 dönüm parsel"
    }
    return descriptions.get(area_type, "Belirsiz alan tipi")

def determine_parcel_type(area_type, size_info):
    """AutoParcelBoundaryRules - Parsel tipini belirle"""
    if area_type == "boundary_adaptive":
        return "Sınır Bazlı Parsel"
    elif area_type == "open_field":
        return "Açık Arazi Parseli"
    elif "_rural" in area_type:
        base_type = area_type.replace("_rural", "").title()
        return f"{base_type} Tarlası"
    elif "building" in area_type:
        return "Bina Parseli"
    else:
        return f"{area_type.title()} Arazisi"

def determine_generation_method(size_info):
    """Üretim metodunu belirle"""
    if isinstance(size_info, str):
        if "engel" in size_info:
            return "Doğal/yapay engellere göre sınır belirleme"
        elif "donum" in size_info:
            return "Alan tipi bazlı boyutlandırma"
        elif "minimum" in size_info:
            return "Açık arazi - minimum 1 dönüm garantisi"
    return "Otomatik sınır analizi"

def extract_boundary_count(size_info):
    """Sınır sayısını çıkar"""
    if isinstance(size_info, str) and "engel" in size_info:
        try:
            return int(size_info.split("_")[0])
        except:
            pass
    return 0

# Kullanıcı İşlemleri

def create_user_token():
    """Yeni kullanıcı token'ı oluştur"""
    return str(uuid.uuid4())

def get_or_create_user(user_token=None):
    """Kullanıcı getir veya yenisini oluştur"""
    print(f"🔍 get_or_create_user çağrıldı - Gelen token: {user_token}")
    
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    if user_token:
        print(f"🔍 Mevcut token aranıyor: {user_token}")
        # Mevcut kullanıcıyı getir
        cursor.execute('SELECT * FROM users WHERE user_token = ?', (user_token,))
        user = cursor.fetchone()
        if user:
            print(f"✅ Mevcut kullanıcı bulundu: {user_token}")
            # Last active güncelle
            cursor.execute('UPDATE users SET last_active = CURRENT_TIMESTAMP WHERE user_token = ?', (user_token,))
            conn.commit()
            conn.close()
            return user_token
        
        print(f"➕ Yeni kullanıcı ekleniyor: {user_token}")
        # Eğer token veritabanında yoksa, yeni kullanıcı olarak ekle
        cursor.execute('INSERT INTO users (user_token, username) VALUES (?, ?)', (user_token, f"User_{user_token[:8]}"))
        conn.commit()
        conn.close()
        return user_token
    
    print("🆕 Yeni token oluşturuluyor...")
    # Yeni kullanıcı oluştur
    new_token = create_user_token()
    cursor.execute('INSERT INTO users (user_token, username) VALUES (?, ?)', (new_token, f"User_{new_token[:8]}"))
    conn.commit()
    conn.close()
    print(f"🆕 Yeni token oluşturuldu: {new_token}")
    return new_token

def save_geojson_parcel_to_db(user_token, parcel_data):
    """GeoJSON parselini veritabanına kaydet"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    # is_merged flag'ini kontrol et
    is_merged = parcel_data.get('is_merged', False)
    
    cursor.execute('''
        INSERT INTO geojson_parcels (user_token, parcel_id, polygon_data, area, properties, is_merged)
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (
        user_token,
        parcel_data['parcel_id'],
        json.dumps(parcel_data['polygon']),
        parcel_data['area'],
        json.dumps(parcel_data.get('properties', {})),
        is_merged
    ))
    
    conn.commit()
    conn.close()

def get_user_geojson_parcels(user_token):
    """Kullanıcının GeoJSON parsellerini getir"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    cursor.execute('SELECT * FROM geojson_parcels WHERE user_token = ?', (user_token,))
    rows = cursor.fetchall()
    conn.close()
    
    parcels = []
    for row in rows:
        parcel = {
            'parcel_id': row[2],
            'polygon': json.loads(row[3]),
            'area': row[4],
            'properties': json.loads(row[5]),
            'is_merged': bool(row[6]),
            'source': 'geojson',
            'created_at': row[7]
        }
        parcels.append(parcel)
    
    return parcels

def get_geojson_parcel_from_db(user_token, parcel_id):
    """Belirli bir GeoJSON parselini getir"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    cursor.execute('SELECT * FROM geojson_parcels WHERE user_token = ? AND parcel_id = ?', (user_token, parcel_id))
    row = cursor.fetchone()
    conn.close()
    
    if row:
        parcel = {
            'parcel_id': row[2],
            'polygon': json.loads(row[3]),
            'area': row[4],
            'properties': json.loads(row[5]),
            'is_merged': bool(row[6]),
            'source': 'geojson',
            'created_at': row[7]
        }
        return parcel
    
    return None

def clear_user_geojson_parcels(user_token):
    """Kullanıcının GeoJSON parsellerini temizle"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    cursor.execute('DELETE FROM geojson_parcels WHERE user_token = ?', (user_token,))
    deleted_count = cursor.rowcount
    conn.commit()
    conn.close()
    
    return deleted_count

# GeoJSONLoader Fonksiyonları

def allowed_file(filename):
    """Dosya uzantısı kontrolü"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def validate_geojson(geojson_data):
    """GeoJSON formatı doğrulama"""
    try:
        if not isinstance(geojson_data, dict):
            return False, "GeoJSON bir dict objesi olmalı"
        
        if geojson_data.get('type') != 'FeatureCollection':
            return False, "GeoJSON tipi 'FeatureCollection' olmalı"
        
        features = geojson_data.get('features', [])
        if not isinstance(features, list):
            return False, "Features bir liste olmalı"
        
        polygon_count = 0
        for feature in features:
            if feature.get('geometry', {}).get('type') in ['Polygon', 'MultiPolygon']:
                polygon_count += 1
        
        if polygon_count == 0:
            return False, "En az bir Polygon veya MultiPolygon bulunmalı"
        
        return True, f"{polygon_count} polygon bulundu"
    except Exception as e:
        return False, f"GeoJSON parse hatası: {str(e)}"

def extract_polygons_from_geojson(geojson_data, clear_existing=True):
    """GeoJSON'dan polygon koordinatlarını çıkar"""
    global geojson_parcels
    if clear_existing:
        geojson_parcels.clear()
    
    features = geojson_data.get('features', [])
    
    for i, feature in enumerate(features):
        geometry = feature.get('geometry', {})
        properties = feature.get('properties', {})
        
        if geometry.get('type') == 'Polygon':
            coordinates = geometry.get('coordinates', [[]])
            if coordinates and len(coordinates) > 0:
                # İlk ring'i al (exterior ring)
                polygon_coords = coordinates[0]
                if len(polygon_coords) > 3:  # En az 4 nokta (kapalı polygon)
                    area = calculate_area_from_coords(polygon_coords)
                    
                    parcel = {
                        "parcel_id": f"geojson_{i+1}",
                        "polygon": polygon_coords,
                        "area": area,
                        "source": "geojson",
                        "properties": properties
                    }
                    geojson_parcels.append(parcel)
        
        elif geometry.get('type') == 'MultiPolygon':
            coordinates = geometry.get('coordinates', [])
            for j, polygon in enumerate(coordinates):
                if polygon and len(polygon) > 0:
                    polygon_coords = polygon[0]  # İlk ring
                    if len(polygon_coords) > 3:
                        area = calculate_area_from_coords(polygon_coords)
                        
                        parcel = {
                            "parcel_id": f"geojson_{i+1}_{j+1}",
                            "polygon": polygon_coords,
                            "area": area,
                            "source": "geojson",
                            "properties": properties
                        }
                        geojson_parcels.append(parcel)
    
    return len(geojson_parcels)

def calculate_area_from_coords(coords):
    """Koordinatlardan alanı hesapla (m²) - Gelişmiş projeksiyon ile"""
    if len(coords) < 3:
        return 0.0
    
    try:
        # EPSG:4326 (WGS84) -> EPSG:3857 (Web Mercator) projeksiyon dönüşümü
        wgs84 = pyproj.CRS('EPSG:4326')
        utm = pyproj.CRS('EPSG:3857')  # Web Mercator - metrik sistem
        project = pyproj.Transformer.from_crs(wgs84, utm, always_xy=True).transform
        
        # Son nokta ilk nokta ile aynıysa çıkar
        if len(coords) > 3 and coords[0] == coords[-1]:
            coords = coords[:-1]
            
        # Koordinatları (lng, lat) formatında Shapely Polygon'a çevir
        if isinstance(coords[0], list) and len(coords[0]) >= 2:
            # [[lng, lat], [lng, lat], ...] formatı
            polygon_coords = [(coord[0], coord[1]) for coord in coords]
        else:
            polygon_coords = coords
            
        # Shapely Polygon oluştur
        polygon_wgs84 = Polygon(polygon_coords)
        
        # Web Mercator (metre) sistemine dönüştür
        polygon_utm = transform(project, polygon_wgs84)
        
        # Gerçek alan hesapla (m²)
        area_m2 = polygon_utm.area
        
        print(f"🔢 Hesaplanan alan: {area_m2:.2f} m² ({area_m2/10000:.4f} hektar)")
        return area_m2
        
    except Exception as e:
        print(f"❌ Gelişmiş alan hesaplama hatası: {str(e)}")
        # Fallback - basit hesaplama
        return calculate_area_simple(coords)

def calculate_area_simple(coords):
    """Basit alan hesaplama (fallback)"""
    try:
        if len(coords) > 3 and coords[0] == coords[-1]:
            coords = coords[:-1]
            
        polygon = Polygon(coords)
        # Kaba hesaplama - 1 derece ≈ 111km
        area_m2 = polygon.area * 111000 * 111000
        
        return area_m2
    except Exception as e:
        print(f"❌ Basit alan hesaplama hatası: {str(e)}")
        return 0.0

def merge_polygons(parcels):
    """Birden fazla parseli birleştir"""
    try:
        if not parcels or len(parcels) < 2:
            return None
        
        print(f"🔗 {len(parcels)} parsel birleştiriliyor...")
        
        # Shapely kullanarak polygon'ları birleştir
        from shapely.geometry import Polygon, MultiPolygon
        from shapely.ops import unary_union
        
        polygons = []
        for parcel in parcels:
            polygon_coords = parcel.get('polygon', [])
            if len(polygon_coords) > 3:
                # GeoJSON koordinatları (lng, lat) -> Shapely (x, y)
                shapely_polygon = Polygon(polygon_coords)
                polygons.append(shapely_polygon)
                print(f"  📍 Parsel eklendi: {len(polygon_coords)} koordinat")
        
        if not polygons:
            return None
        
        # Tüm polygon'ları birleştir
        if len(polygons) == 1:
            merged = polygons[0]
        else:
            merged = unary_union(polygons)
        
        print(f"🔗 Birleştirme sonucu: {merged.geom_type}")
        
        # Sonucu GeoJSON formatına çevir
        if merged.geom_type == 'Polygon':
            coords = list(merged.exterior.coords)
            print(f"✅ Tek polygon: {len(coords)} koordinat")
        elif merged.geom_type == 'MultiPolygon':
            # MultiPolygon'ı tek polygon'a çevir - tüm parçaları birleştir
            print(f"🔗 MultiPolygon tespit edildi: {len(merged.geoms)} parça")
            
            # Tüm polygon'ları tek bir union ile birleştir
            from shapely.ops import unary_union
            single_polygon = unary_union(merged.geoms)
            
            if single_polygon.geom_type == 'Polygon':
                coords = list(single_polygon.exterior.coords)
                print(f"✅ MultiPolygon tek polygon'a dönüştürüldü: {len(coords)} koordinat")
            else:
                # Hala MultiPolygon ise, en büyük parçayı al
                largest_polygon = max(single_polygon.geoms, key=lambda p: p.area)
                coords = list(largest_polygon.exterior.coords)
                print(f"✅ En büyük parça seçildi: {len(coords)} koordinat")
        else:
            return None
        
        print(f"✅ Parseller başarıyla birleştirildi - {len(coords)} koordinat")
        return coords
        
    except Exception as e:
        print(f"❌ Parsel birleştirme hatası: {str(e)}")
        return None

# GeoJSONLoader API Endpoints

@app.route('/api/uploadGeoJSON', methods=['POST', 'OPTIONS'])
def upload_geojson():
    """GeoJSON dosyası yükle ve parse et"""
    print("🚀 upload_geojson fonksiyonu çağrıldı!")
    print(f"🚀 Request method: {request.method}")
    
    if request.method == 'OPTIONS':
        print("🚀 OPTIONS request - CORS response")
        return '', 200
    
    try:
        # Kullanıcı token kontrolü
        print(f"🔍 Request headers: {dict(request.headers)}")
        print(f"🔍 Request form: {dict(request.form)}")
        
        user_token = request.headers.get('User-Token') or request.form.get('user_token')
        print(f"🔍 Alınan token: {user_token}")
        
        if not user_token:
            print("❌ Kullanıcı token bulunamadı!")
            return jsonify({"error": "Kullanıcı token gerekli"}), 400
        
        # Token'ı veritabanına kaydet (eğer yoksa)
        print(f"🔍 get_or_create_user çağrılmadan önce token: {user_token}")
        user_token = get_or_create_user(user_token)
        print(f"🔍 get_or_create_user çağrıldıktan sonra token: {user_token}")
        
        print(f"📝 Kullanıcı token: {user_token}")
        print(f"📝 Token uzunluğu: {len(user_token)}")
        # Dosya kontrolü
        if 'file' not in request.files:
            return jsonify({"error": "Dosya bulunamadı"}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "Dosya seçilmedi"}), 400
        
        if not allowed_file(file.filename):
            return jsonify({"error": "Sadece .geojson veya .json dosyaları kabul edilir"}), 400
        
        # Dosyayı oku
        content = file.read().decode('utf-8')
        geojson_data = json.loads(content)
        
        # GeoJSON doğrulama
        is_valid, message = validate_geojson(geojson_data)
        if not is_valid:
            return jsonify({"error": f"Geçersiz GeoJSON: {message}"}), 400
        
        # Polygon'ları çıkar ve veritabanına kaydet
        features = geojson_data.get('features', [])
        saved_parcels = []
        
        # Benzersiz parsel ID'si için timestamp ve dosya adı kullan
        timestamp = int(time.time() * 1000)  # milisaniye
        file_hash = hash(file.filename + str(timestamp)) % 10000  # Dosya hash'i
        
        for i, feature in enumerate(features):
            geometry = feature.get('geometry', {})
            properties = feature.get('properties', {})
            
            if geometry.get('type') == 'Polygon':
                coordinates = geometry.get('coordinates', [[]])
                if coordinates and len(coordinates) > 0:
                    polygon_coords = coordinates[0]
                    if len(polygon_coords) > 3:
                        # Önce hesaplanan alanı al
                        calculated_area = calculate_area_from_coords(polygon_coords)
                        
                        # TKGM properties'teki alan değerini kontrol et (önce TapuAlani, sonra Alan)
                        tkgm_area_str = properties.get('TapuAlani', '') or properties.get('Alan', '')
                        print(f"🔍 TKGM Alan string: '{tkgm_area_str}'")
                        
                        # TKGM alan değerini m²'ye çevir
                        tkgm_area_m2 = None
                        if tkgm_area_str:
                            try:
                                # "1.092,58" formatı için özel işlem (önce kontrol et)
                                if '.' in tkgm_area_str and ',' in tkgm_area_str:
                                    # "1.092,58" -> "1092.58"
                                    parts = tkgm_area_str.split(',')
                                    if len(parts) == 2:
                                        integer_part = parts[0].replace('.', '')  # "1.092" -> "1092"
                                        decimal_part = parts[1]  # "58"
                                        tkgm_area_m2 = float(f"{integer_part}.{decimal_part}")
                                        print(f"✅ TKGM Alan özel format parse edildi: {tkgm_area_str} → {tkgm_area_m2} m²")
                                else:
                                    # Normal format - virgülü nokta ile değiştir
                                    tkgm_area_clean = tkgm_area_str.replace(',', '.')
                                    tkgm_area_m2 = float(tkgm_area_clean)
                                    print(f"✅ TKGM Alan normal format: {tkgm_area_str} → {tkgm_area_m2} m²")
                                    
                            except ValueError as e:
                                print(f"❌ TKGM Alan değeri parse edilemedi: '{tkgm_area_str}' - Hata: {e}")
                        
                        # Hangi alan değerini kullanacağımızı belirle
                        final_area = calculated_area
                        if tkgm_area_m2 is not None:
                            # TKGM değeri varsa onu kullan
                            final_area = tkgm_area_m2
                            print(f"✅ TKGM alan değeri kullanılıyor: {final_area} m²")
                        else:
                            print(f"✅ Hesaplanan alan kullanılıyor: {final_area} m²")
                        
                        parcel_data = {
                            "parcel_id": f"geojson_{user_token}_{timestamp}_{file_hash}_{i+1}",
                            "polygon": polygon_coords,
                            "area": final_area,
                            "source": "geojson",
                            "properties": properties
                        }
                        
                        # Veritabanına kaydet
                        save_geojson_parcel_to_db(user_token, parcel_data)
                        saved_parcels.append(parcel_data)
        
        # Dosyayı kaydet (opsiyonel)
        filename = secure_filename(file.filename)
        user_folder = os.path.join(app.config['UPLOAD_FOLDER'], user_token[:8])
        os.makedirs(user_folder, exist_ok=True)
        file_path = os.path.join(user_folder, filename)
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(geojson_data, f, ensure_ascii=False, indent=2)
        
        return jsonify({
            "success": True,
            "message": f"GeoJSON başarıyla yüklendi - {len(saved_parcels)} parsel bulundu",
            "polygon_count": len(saved_parcels),
            "filename": filename,
            "user_token": user_token,
            "parcels": saved_parcels
        }), 200
        
    except json.JSONDecodeError:
        return jsonify({"error": "Geçersiz JSON formatı"}), 400
    except Exception as e:
        return jsonify({"error": f"Dosya yükleme hatası: {str(e)}"}), 500

@app.route('/api/mergeGeoJSONParcels', methods=['POST', 'OPTIONS'])
def merge_geojson_parcels():
    """Seçilen GeoJSON parsellerini birleştir"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        # Kullanıcı token kontrolü
        user_token = request.headers.get('User-Token') or request.form.get('user_token')
        if not user_token:
            return jsonify({"error": "User token gerekli"}), 400
        
        # Birleştirilecek parsel ID'lerini al
        data = request.get_json()
        parcel_ids = data.get('parcel_ids', [])
        
        if not parcel_ids or len(parcel_ids) < 2:
            return jsonify({"error": "En az 2 parsel seçilmelidir"}), 400
        
        print(f"🔗 Parseller birleştiriliyor: {parcel_ids}")
        
        # Parselleri veritabanından al
        parcels = []
        for parcel_id in parcel_ids:
            parcel = get_geojson_parcel_from_db(user_token, parcel_id)
            if parcel:
                parcels.append(parcel)
        
        if len(parcels) < 2:
            return jsonify({"error": "Seçilen parseller bulunamadı"}), 400
        
        # Parselleri birleştir
        merged_polygon = merge_polygons(parcels)
        if not merged_polygon:
            return jsonify({"error": "Parseller birleştirilemedi"}), 400
        
        # Birleştirilmiş alanı hesapla - orijinal parsellerin alanlarını topla
        merged_area = sum(parcel.get('area', 0) for parcel in parcels)
        print(f"🔢 Birleştirilmiş alan hesaplandı: {merged_area:.2f} m² (orijinal parsellerin toplamı)")
        
        # Birleştirilmiş parseli kaydet
        merged_parcel_data = {
            "parcel_id": f"merged_{user_token[:8]}_{int(time.time())}",
            "polygon": merged_polygon,
            "area": merged_area,
            "source": "merged",
            "is_merged": True,  # Birleştirilmiş parsel flag'i
            "properties": {
                "merged_from": parcel_ids,
                "original_count": len(parcels),
                "merged_at": datetime.now().isoformat()
            }
        }
        
        # Veritabanına kaydet
        save_geojson_parcel_to_db(user_token, merged_parcel_data)
        
        # Orijinal parselleri sil (opsiyonel)
        # for parcel_id in parcel_ids:
        #     delete_geojson_parcel_from_db(user_token, parcel_id)
        
        return jsonify({
            "success": True,
            "message": f"{len(parcels)} parsel başarıyla birleştirildi",
            "merged_parcel": merged_parcel_data,
            "original_parcels": parcel_ids
        }), 200
        
    except Exception as e:
        return jsonify({"error": f"Parsel birleştirme hatası: {str(e)}"}), 500

@app.route('/api/getGeoJSONParcels', methods=['GET', 'OPTIONS'])
def get_geojson_parcels():
    """Yüklenen GeoJSON parsellerini al"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        # Kullanıcı token kontrolü
        user_token = request.headers.get('User-Token') or request.args.get('user_token')
        if not user_token:
            return jsonify({"error": "User token gerekli"}), 400
        
        # Kullanıcının parsellerini getir
        parcels = get_user_geojson_parcels(user_token)
        
        return jsonify({
            "success": True,
            "parcel_count": len(parcels),
            "user_token": user_token,
            "parcels": parcels
        }), 200
    except Exception as e:
        return jsonify({"error": f"Parsel getirme hatası: {str(e)}"}), 500

@app.route('/api/clearGeoJSONParcels', methods=['POST', 'OPTIONS'])
def clear_geojson_parcels():
    """GeoJSON parsellerini temizle"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        # Kullanıcı token kontrolü
        user_token = request.headers.get('User-Token') or request.json.get('user_token') if request.json else None
        if not user_token:
            return jsonify({"error": "User token gerekli"}), 400
        
        # Kullanıcının parsellerini temizle
        cleared_count = clear_user_geojson_parcels(user_token)
        
        return jsonify({
            "success": True,
            "message": f"{cleared_count} parsel temizlendi",
            "user_token": user_token
        }), 200
    except Exception as e:
        return jsonify({"error": f"Parsel temizleme hatası: {str(e)}"}), 500

# ===== ÇİFTLİK TASARIM KAYDETME SİSTEMİ =====

@app.route('/api/saveFarmDesign', methods=['POST', 'OPTIONS'])
def save_farm_design():
    """Çiftlik tasarımını kaydet"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "JSON verisi gerekli"}), 400
        
        # Kullanıcı token kontrolü
        user_token = request.headers.get('User-Token') or data.get('user_token')
        if not user_token:
            return jsonify({"error": "User token gerekli"}), 400
        
        # Tasarım verilerini al
        design_name = data.get('design_name', f'Tasarım_{datetime.now().strftime("%Y%m%d_%H%M%S")}')
        design_data = data.get('design_data', {})
        geojson_parcels = data.get('geojson_parcels', [])
        
        # Veritabanına kaydet
        design_id = save_farm_design_to_db(user_token, design_name, design_data, geojson_parcels)
        
        return jsonify({
            "success": True,
            "message": "Tasarım başarıyla kaydedildi",
            "design_id": design_id,
            "design_name": design_name,
            "user_token": user_token
        }), 200
        
    except Exception as e:
        return jsonify({"error": f"Tasarım kaydetme hatası: {str(e)}"}), 500

@app.route('/api/getFarmDesigns', methods=['GET', 'OPTIONS'])
def get_farm_designs():
    """Kullanıcının çiftlik tasarımlarını listele"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        # Kullanıcı token kontrolü
        user_token = request.headers.get('User-Token') or request.args.get('user_token')
        if not user_token:
            return jsonify({"error": "User token gerekli"}), 400
        
        # Tasarımları getir
        designs = get_user_farm_designs(user_token)
        
        return jsonify({
            "success": True,
            "designs": designs,
            "count": len(designs),
            "user_token": user_token
        }), 200
        
    except Exception as e:
        return jsonify({"error": f"Tasarım listeleme hatası: {str(e)}"}), 500

@app.route('/api/loadFarmDesign', methods=['POST', 'OPTIONS'])
def load_farm_design():
    """Çiftlik tasarımını yükle"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "JSON verisi gerekli"}), 400
        
        # Kullanıcı token kontrolü
        user_token = request.headers.get('User-Token') or data.get('user_token')
        design_id = data.get('design_id')
        
        if not user_token or not design_id:
            return jsonify({"error": "User token ve design_id gerekli"}), 400
        
        # Tasarımı getir
        design = load_farm_design_from_db(user_token, design_id)
        
        if not design:
            return jsonify({"error": "Tasarım bulunamadı"}), 404
        
        return jsonify({
            "success": True,
            "design": design,
            "user_token": user_token
        }), 200
        
    except Exception as e:
        return jsonify({"error": f"Tasarım yükleme hatası: {str(e)}"}), 500

@app.route('/api/deleteFarmDesign', methods=['DELETE', 'OPTIONS'])
def delete_farm_design():
    """Çiftlik tasarımını sil"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "JSON verisi gerekli"}), 400
        
        # Kullanıcı token kontrolü
        user_token = request.headers.get('User-Token') or data.get('user_token')
        design_id = data.get('design_id')
        
        if not user_token or not design_id:
            return jsonify({"error": "User token ve design_id gerekli"}), 400
        
        # Tasarımı sil
        deleted = delete_farm_design_from_db(user_token, design_id)
        
        if not deleted:
            return jsonify({"error": "Tasarım bulunamadı veya silinemedi"}), 404
        
        return jsonify({
            "success": True,
            "message": "Tasarım başarıyla silindi",
            "design_id": design_id,
            "user_token": user_token
        }), 200
        
    except Exception as e:
        return jsonify({"error": f"Tasarım silme hatası: {str(e)}"}), 500

# ===== VERİTABANI FONKSİYONLARI =====

def save_farm_design_to_db(user_token, design_name, design_data, geojson_parcels):
    """Çiftlik tasarımını veritabanına kaydet"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    try:
        # Tasarım verilerini JSON string'e çevir
        design_data_json = json.dumps(design_data, ensure_ascii=False)
        geojson_parcels_json = json.dumps(geojson_parcels, ensure_ascii=False)
        
        cursor.execute('''
            INSERT INTO farm_designs (user_token, design_name, design_data, geojson_parcels)
            VALUES (?, ?, ?, ?)
        ''', (user_token, design_name, design_data_json, geojson_parcels_json))
        
        design_id = cursor.lastrowid
        conn.commit()
        
        print(f"✅ Tasarım kaydedildi: {design_name} (ID: {design_id})")
        return design_id
        
    except Exception as e:
        conn.rollback()
        print(f"❌ Tasarım kaydetme hatası: {e}")
        raise e
    finally:
        conn.close()

def get_user_farm_designs(user_token):
    """Kullanıcının çiftlik tasarımlarını getir"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            SELECT id, design_name, design_data, geojson_parcels, created_at, updated_at
            FROM farm_designs 
            WHERE user_token = ? AND is_active = 1
            ORDER BY updated_at DESC
        ''', (user_token,))
        
        designs = []
        for row in cursor.fetchall():
            design_id, design_name, design_data_json, geojson_parcels_json, created_at, updated_at = row
            
            # JSON string'leri parse et
            design_data = json.loads(design_data_json) if design_data_json else {}
            geojson_parcels = json.loads(geojson_parcels_json) if geojson_parcels_json else []
            
            designs.append({
                'id': design_id,
                'design_name': design_name,
                'design_data': design_data,
                'geojson_parcels': geojson_parcels,
                'created_at': created_at,
                'updated_at': updated_at
            })
        
        print(f"✅ {len(designs)} tasarım getirildi (User: {user_token})")
        return designs
        
    except Exception as e:
        print(f"❌ Tasarım listeleme hatası: {e}")
        raise e
    finally:
        conn.close()

def load_farm_design_from_db(user_token, design_id):
    """Çiftlik tasarımını veritabanından yükle"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            SELECT design_name, design_data, geojson_parcels, created_at, updated_at
            FROM farm_designs 
            WHERE id = ? AND user_token = ? AND is_active = 1
        ''', (design_id, user_token))
        
        row = cursor.fetchone()
        if not row:
            return None
        
        design_name, design_data_json, geojson_parcels_json, created_at, updated_at = row
        
        # JSON string'leri parse et
        design_data = json.loads(design_data_json) if design_data_json else {}
        geojson_parcels = json.loads(geojson_parcels_json) if geojson_parcels_json else []
        
        design = {
            'id': design_id,
            'design_name': design_name,
            'design_data': design_data,
            'geojson_parcels': geojson_parcels,
            'created_at': created_at,
            'updated_at': updated_at
        }
        
        print(f"✅ Tasarım yüklendi: {design_name} (ID: {design_id})")
        return design
        
    except Exception as e:
        print(f"❌ Tasarım yükleme hatası: {e}")
        raise e
    finally:
        conn.close()

def delete_farm_design_from_db(user_token, design_id):
    """Çiftlik tasarımını veritabanından sil (soft delete)"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            UPDATE farm_designs 
            SET is_active = 0, updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND user_token = ? AND is_active = 1
        ''', (design_id, user_token))
        
        deleted = cursor.rowcount > 0
        conn.commit()
        
        if deleted:
            print(f"✅ Tasarım silindi (ID: {design_id})")
        else:
            print(f"❌ Tasarım bulunamadı (ID: {design_id})")
        
        return deleted
        
    except Exception as e:
        conn.rollback()
        print(f"❌ Tasarım silme hatası: {e}")
        raise e
    finally:
        conn.close()

if __name__ == '__main__':
    print("🚀 Flask uygulaması başlatılıyor...")
    print("🚀 Port: 5000")
    print("🚀 Host: 0.0.0.0")
    print("🚀 Route'lar:")
    for rule in app.url_map.iter_rules():
        print(f"  - {rule.rule} [{', '.join(rule.methods)}]")
    app.run(host='0.0.0.0', port=5000)
