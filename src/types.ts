export type AssetType =
  | 'agac'
  | 'yapi'
  | 'kuyu'
  | 'sensor'
  | 'gunes'
  | 'olcum'
  | 'su_borusu'
  | 'elektrik_kablo'
  | 'trafo';

export interface LatLng {
  lat: number;
  lng: number;
}

export interface GeometryPoint {
  type: 'Point';
  coordinates: [number, number]; // [lng, lat]
}

export interface GeometryLineString {
  type: 'LineString';
  coordinates: [number, number][]; // [[lng, lat], [lng, lat], ...]
}

export interface GeometryPolygon {
  type: 'Polygon' | 'MultiPolygon';
  coordinates: any;
}

export type AssetGeometry = GeometryPoint | GeometryLineString | GeometryPolygon;

export interface DigitalCardGenel {
  notes?: string;
  photo_urls?: string;
  asset_code?: string;
}

export interface DigitalCardAgac {
  species?: string;
  variety?: string;
  age_years?: string;
  planting_date?: string;
  rootstock?: string;
  row_no?: string;
  tree_no?: string;
  ndvi_score?: number;
}

export interface DigitalCardSaglik {
  disease_name?: string;
  symptoms?: string;
  pest_name?: string;
  severity?: string;
  treatment_plan?: string;
}

export interface DigitalCardIoT {
  soil_moisture_pct?: string | number;
  soil_moisture_deep_pct?: string | number;
  trunk_temperature_c?: string | number;
  air_temperature_c?: string | number;
  air_humidity_pct?: string | number;
  soil_ph?: string | number;
  soil_ec?: string | number;
  battery_pct?: string | number;
  signal_dbm?: string | number;
  last_seen_at?: string;
}

/**
 * Solar Power Plant (GES) Specialized Telemetry
 */
export interface DigitalCardSolar {
  current_power_kw: number;
  daily_yield_kwh: number;
  peak_power_kwp: number;
  inverter_efficiency_pct: number;
  panel_temperature_c: number;
  irradiance_w_m2: number;
  inverter_status: 'sebeke_bagli' | 'ada_modu' | 'hata';
  grid_voltage_v: number;
  total_energy_mwh?: number;
}

/**
 * Deep Well Submersible Pump Specialized Telemetry
 */
export interface DigitalCardWellPump {
  well_depth_m: number;
  static_water_level_m: number;
  dynamic_water_level_m: number;
  flow_rate_m3_h: number;
  daily_volume_m3: number;
  line_pressure_bar: number;
  motor_power_kw: number;
  motor_current_a: number;
  motor_voltage_v: number;
  motor_status: 'calisiyor' | 'durdu' | 'ariza';
  dry_run_protection_ok: boolean;
}

/**
 * Electrical Infrastructure / Transformer Specialized Specs
 */
export interface DigitalCardElectricInfra {
  transformer_capacity_kva: number;
  primary_voltage_kv: number;
  secondary_voltage_v: number;
  active_load_kw: number;
  power_factor: number;
  oil_temperature_c: number;
  cable_spec: string;
  line_length_m?: number;
  status: 'aktif' | 'kesinti' | 'bakimda';
}

/**
 * Water Pipeline / Irrigation Network Specialized Specs
 */
export interface DigitalCardWaterInfra {
  pipe_spec: string; // e.g. "Ø90 mm PN10 HDPE 100"
  nominal_diameter_mm: number;
  line_pressure_bar: number;
  flow_velocity_m_s: number;
  valve_status: 'acik' | 'kapali' | 'kismi';
  filter_dp_bar: number; // Differential pressure across filters
  line_length_m?: number;
  target_zone?: string;
}

export interface DigitalCardBakim {
  last_irrigation_at?: string;
  last_pruning_at?: string;
  last_fertilization_at?: string;
  last_spray_at?: string;
}

export interface DigitalCardUretim {
  last_yield_kg?: string;
  expected_yield_kg?: string;
  fruit_count_est?: string;
}

export interface DigitalCardAlarm {
  soil_moisture_min?: string | number;
  soil_moisture_max?: string | number;
  air_temperature_min?: string | number;
  air_temperature_max?: string | number;
}

export interface DigitalCard {
  genel?: DigitalCardGenel;
  agac?: DigitalCardAgac;
  saglik?: DigitalCardSaglik;
  iot?: DigitalCardIoT;
  solar?: DigitalCardSolar;
  well_pump?: DigitalCardWellPump;
  electric_infra?: DigitalCardElectricInfra;
  water_infra?: DigitalCardWaterInfra;
  bakim?: DigitalCardBakim;
  uretim?: DigitalCardUretim;
  alarm?: DigitalCardAlarm;
}

export interface LayerVisibilityState {
  trees: boolean;
  buildings: boolean;
  water: boolean;
  electric: boolean;
  sensors: boolean;
  cadastre: boolean;
  grid: boolean;
}

export interface AuditLogEntry {
  at: string;
  event: string;
  user?: string;
}

export interface CanonicalAsset {
  asset_id: string;
  /** Varlığın ait olduğu parselin kararlı kimliği (bkz. getParcelId). */
  parcel_id?: string;
  name: string;
  type: 'Point' | 'LineString' | 'Polygon';
  geometry: GeometryPoint | GeometryLineString | GeometryPolygon;
  style: {
    color: string;
    icon: AssetType;
  };
  properties: {
    iot_connected?: boolean;
    local_x_m?: number;
    local_y_m?: number;
    local_origin?: string;
    digital_card?: DigitalCard;
    meta?: {
      asset_id?: string;
      geometry_type?: string;
      asset_type?: string;
      category?: string;
      version?: number;
    };
    timestamps?: {
      created_at?: string;
      updated_at?: string;
      last_operation?: string;
      timezone_offset_min?: string;
      timezone_name?: string;
    };
    audit_log?: AuditLogEntry[];
    [key: string]: any;
  };
}

export interface ParcelProperties {
  ParselNo?: string;
  Alan?: string;
  Mevkii?: string;
  Nitelik?: string;
  Ada?: string;
  Il?: string;
  Ilce?: string;
  Mahalle?: string;
  Pafta?: string;
  TapuAlani?: string;
  name?: string;
  area_type?: string;
  owner?: string;
  [key: string]: any;
}

export interface ParcelFeature {
  type: 'Feature';
  geometry: GeometryPolygon;
  properties: ParcelProperties;
}

export interface ParcelCollection {
  type: 'FeatureCollection';
  features: ParcelFeature[];
  name?: string;
}

export type WorkOrderPriority = 'dusuk' | 'normal' | 'yuksek' | 'acil';
export type WorkOrderStatus = 'bekliyor' | 'devam_ediyor' | 'tamamlandi' | 'iptal';

export interface WorkOrder {
  work_order_id: string;
  asset_id: string;
  asset_name?: string;
  title: string;
  description: string;
  assignee: string;
  priority: WorkOrderPriority;
  status: WorkOrderStatus;
  created_at: string;
  due_at?: string;
  completed_at?: string;
  note?: string;
}

export interface IoTTelemetry {
  schema_version: string;
  asset_id: string;
  device_id: string;
  metrics: {
    soil_moisture_pct?: number;
    trunk_temperature_c?: number;
    air_temperature_c?: number;
    air_humidity_pct?: number;
    soil_ph?: number;
    battery_pct?: number;
  };
  alerts: string[];
  measured_at: string;
  quality_flag?: string;
}

export interface FarmKpi {
  assets_total: number;
  work_orders_open: number;
  alerts_count: number;
  trees_count: number;
  wells_count: number;
  sensors_count: number;
  solar_count: number;
}

export interface UserAccount {
  id: string;
  username: string;
  email: string;
  role: 'superadmin' | 'admin' | 'operator' | 'viewer';
  created_at: string;
  last_login?: string;
}
