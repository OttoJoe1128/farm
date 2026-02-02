-- SmartFarm XR Database Schema
-- Turkish: Akıllı Çiftlik Veritabanı Şeması

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table / Kullanıcılar tablosu
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Saved locations table / Kayıtlı lokasyonlar tablosu
CREATE TABLE saved_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    zoom_level INTEGER DEFAULT 15,
    area_size_m2 DECIMAL(12, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, name)
);

-- Farm designs table / Çiftlik tasarımları tablosu
CREATE TABLE farm_designs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    location_id UUID NOT NULL REFERENCES saved_locations(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    grid_width INTEGER NOT NULL,
    grid_height INTEGER NOT NULL,
    cell_size_meters DECIMAL(5, 2) NOT NULL,
    design_data JSONB NOT NULL, -- Grid layout and object positions
    version INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Object types table / Obje türleri tablosu
CREATE TABLE object_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    display_name_tr VARCHAR(100) NOT NULL, -- Turkish display name
    display_name_en VARCHAR(100) NOT NULL, -- English display name
    category VARCHAR(50) NOT NULL, -- building, water, energy, agriculture, monitoring
    icon_name VARCHAR(50),
    properties_schema JSONB, -- JSON schema for object properties
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert default object types
INSERT INTO object_types (name, display_name_tr, display_name_en, category, icon_name, properties_schema) VALUES
-- Buildings / Binalar
('farmhouse', 'Çiftlik Evi', 'Farmhouse', 'building', 'home', '{"rooms": {"type": "integer", "min": 1}, "size_m2": {"type": "number", "min": 0}, "year_built": {"type": "integer"}}'),
('barn', 'Ahır', 'Barn', 'building', 'home_work', '{"capacity_animals": {"type": "integer", "min": 0}, "size_m2": {"type": "number", "min": 0}}'),
('warehouse', 'Depo', 'Warehouse', 'building', 'warehouse', '{"capacity_m3": {"type": "number", "min": 0}, "temperature_controlled": {"type": "boolean"}}'),
('greenhouse', 'Sera', 'Greenhouse', 'building', 'energy_savings_leaf', '{"size_m2": {"type": "number", "min": 0}, "climate_controlled": {"type": "boolean"}, "crop_type": {"type": "string"}}'),

-- Water Systems / Su Sistemleri
('water_tank', 'Su Deposu', 'Water Tank', 'water', 'water_drop', '{"capacity_liters": {"type": "integer", "min": 0}, "current_level": {"type": "number", "min": 0, "max": 100}, "material": {"type": "string"}}'),
('water_pump', 'Su Pompası', 'Water Pump', 'water', 'water_pump', '{"flow_rate_lpm": {"type": "number", "min": 0}, "power_watts": {"type": "number", "min": 0}, "depth_meters": {"type": "number", "min": 0}}'),
('water_well', 'Su Kuyusu', 'Water Well', 'water', 'opacity', '{"depth_meters": {"type": "number", "min": 0}, "water_quality": {"type": "string"}, "flow_rate_lpm": {"type": "number", "min": 0}}'),

-- Energy Systems / Enerji Sistemleri
('solar_panel', 'Güneş Paneli', 'Solar Panel', 'energy', 'solar_power', '{"wattage": {"type": "number", "min": 0}, "efficiency_percent": {"type": "number", "min": 0, "max": 100}, "angle_degrees": {"type": "number", "min": 0, "max": 90}}'),
('battery_storage', 'Batarya Depolama', 'Battery Storage', 'energy', 'battery_full', '{"capacity_kwh": {"type": "number", "min": 0}, "current_charge": {"type": "number", "min": 0, "max": 100}}'),

-- Agriculture / Tarım
('tree', 'Ağaç', 'Tree', 'agriculture', 'park', '{"species": {"type": "string"}, "age_years": {"type": "integer", "min": 0}, "height_meters": {"type": "number", "min": 0}, "health_status": {"type": "string", "enum": ["excellent", "good", "fair", "poor"]}}'),
('crop_field', 'Tarla', 'Crop Field', 'agriculture', 'grass', '{"crop_type": {"type": "string"}, "planting_date": {"type": "string", "format": "date"}, "harvest_date": {"type": "string", "format": "date"}}'),

-- Monitoring / İzleme
('sensor', 'Sensör', 'Sensor', 'monitoring', 'sensors', '{"sensor_type": {"type": "string"}, "measurement_unit": {"type": "string"}, "min_value": {"type": "number"}, "max_value": {"type": "number"}}'),
('camera', 'Kamera', 'Camera', 'monitoring', 'camera_alt', '{"resolution": {"type": "string"}, "night_vision": {"type": "boolean"}, "coverage_angle": {"type": "number", "min": 0, "max": 360}}'),

-- Infrastructure / Altyapı
('fence', 'Çit', 'Fence', 'infrastructure', 'fence', '{"material": {"type": "string"}, "height_meters": {"type": "number", "min": 0}, "length_meters": {"type": "number", "min": 0}}'),
('pipe', 'Boru', 'Pipe', 'infrastructure', 'plumbing', '{"diameter_mm": {"type": "number", "min": 0}, "material": {"type": "string"}, "pressure_rating": {"type": "number", "min": 0}}'),
('cable', 'Kablo', 'Cable', 'infrastructure', 'cable', '{"type": {"type": "string", "enum": ["power", "data", "control"]}, "voltage": {"type": "number", "min": 0}, "length_meters": {"type": "number", "min": 0}}');

-- Farm objects table / Çiftlik objeleri tablosu
CREATE TABLE farm_objects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    design_id UUID NOT NULL REFERENCES farm_designs(id) ON DELETE CASCADE,
    object_type_id UUID NOT NULL REFERENCES object_types(id),
    name VARCHAR(100),
    description TEXT,
    grid_row INTEGER NOT NULL,
    grid_col INTEGER NOT NULL,
    properties JSONB, -- Object-specific properties
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Line objects table / Çizgi objeleri tablosu (for fences, pipes, cables)
CREATE TABLE line_objects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    design_id UUID NOT NULL REFERENCES farm_designs(id) ON DELETE CASCADE,
    object_type_id UUID NOT NULL REFERENCES object_types(id),
    name VARCHAR(100),
    description TEXT,
    points JSONB NOT NULL, -- Array of {row, col} coordinates
    properties JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Design history table / Tasarım geçmişi tablosu
CREATE TABLE design_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    design_id UUID NOT NULL REFERENCES farm_designs(id) ON DELETE CASCADE,
    version INTEGER NOT NULL,
    change_description TEXT,
    design_data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- Indexes for performance
CREATE INDEX idx_saved_locations_user_id ON saved_locations(user_id);
CREATE INDEX idx_farm_designs_location_id ON farm_designs(location_id);
CREATE INDEX idx_farm_objects_design_id ON farm_objects(design_id);
CREATE INDEX idx_line_objects_design_id ON line_objects(design_id);
CREATE INDEX idx_design_history_design_id ON design_history(design_id);

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply update timestamp triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_saved_locations_updated_at BEFORE UPDATE ON saved_locations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_farm_designs_updated_at BEFORE UPDATE ON farm_designs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_farm_objects_updated_at BEFORE UPDATE ON farm_objects FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_line_objects_updated_at BEFORE UPDATE ON line_objects FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
