import { LatLng, CanonicalAsset, ParcelFeature, AssetType, LayerVisibilityState } from '../types';

const EARTH_RADIUS_METERS = 6378137.0;

/**
 * Converts Latitude and Longitude to Web Mercator meters (EPSG:3857)
 */
export function latLonToMeters(lat: number, lon: number): [number, number] {
  const clampedLat = Math.max(Math.min(lat, 85.05112878), -85.05112878);
  const x = EARTH_RADIUS_METERS * (lon * Math.PI / 180.0);
  const y = EARTH_RADIUS_METERS * Math.log(Math.tan(Math.PI / 4.0 + (clampedLat * Math.PI / 180.0) / 2.0));
  return [x, y];
}

/**
 * Converts Web Mercator meters back to Latitude and Longitude
 */
export function metersToLatLon(x: number, y: number): [number, number] {
  const lon = (x / EARTH_RADIUS_METERS) * (180.0 / Math.PI);
  const lat = (2.0 * Math.atan(Math.exp(y / EARTH_RADIUS_METERS)) - Math.PI / 2.0) * (180.0 / Math.PI);
  return [lat, lon];
}

/**
 * Calculates Haversine distance in meters between two lat/lng points
 */
export function haversineDistanceMeters(p1: LatLng, p2: LatLng): number {
  const R = 6371e3; // meters
  const phi1 = (p1.lat * Math.PI) / 180;
  const phi2 = (p2.lat * Math.PI) / 180;
  const deltaPhi = ((p2.lat - p1.lat) * Math.PI) / 180;
  const deltaLambda = ((p2.lng - p1.lng) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

/**
 * Ray-casting algorithm to test if a point is inside a polygon or multipolygon
 */
export function isPointInPolygon(point: LatLng, polygon: ParcelFeature): boolean {
  const geom = polygon.geometry;
  if (!geom || !geom.coordinates) return false;

  const rings: [number, number][][] = [];
  if (geom.type === 'Polygon') {
    if (geom.coordinates.length > 0) {
      rings.push(geom.coordinates[0]);
    }
  } else if (geom.type === 'MultiPolygon') {
    for (const poly of geom.coordinates) {
      if (poly.length > 0) {
        rings.push(poly[0]);
      }
    }
  }

  for (const ring of rings) {
    let inside = false;
    for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      const xi = ring[i][0]; // lng
      const yi = ring[i][1]; // lat
      const xj = ring[j][0];
      const yj = ring[j][1];

      const intersect =
        yi > point.lat !== yj > point.lat &&
        point.lng < ((xj - xi) * (point.lat - yi)) / (yj - yi) + xi;
      if (intersect) inside = !inside;
    }
    if (inside) return true;
  }

  return false;
}

/**
 * Calculate local (x, y) meters relative to the parcel's first vertex
 */
export function calculateLocalMeters(point: LatLng, parcel: ParcelFeature): { local_x_m: number; local_y_m: number } {
  try {
    const geom = parcel.geometry;
    let originCoord: [number, number] | null = null;
    if (geom.type === 'Polygon' && geom.coordinates?.[0]?.[0]) {
      originCoord = geom.coordinates[0][0];
    } else if (geom.type === 'MultiPolygon' && geom.coordinates?.[0]?.[0]?.[0]) {
      originCoord = geom.coordinates[0][0][0];
    }

    if (!originCoord) {
      return { local_x_m: 0, local_y_m: 0 };
    }

    const [originX, originY] = latLonToMeters(originCoord[1], originCoord[0]);
    const [pointX, pointY] = latLonToMeters(point.lat, point.lng);

    return {
      local_x_m: parseFloat((pointX - originX).toFixed(2)),
      local_y_m: parseFloat((pointY - originY).toFixed(2)),
    };
  } catch {
    return { local_x_m: 0, local_y_m: 0 };
  }
}

export interface GridLineSegment {
  p1: [number, number]; // [lat, lng]
  p2: [number, number]; // [lat, lng]
  isMajor?: boolean;
}

/**
 * Snaps a target click to either the nearest parcel vertex or grid intersection
 */
export function snapToParcelOrGrid(
  targetPoint: LatLng,
  parcel: ParcelFeature,
  thresholdMeters: number = 2.0,
  gridCellSize: number = 2.0
): { snappedPoint: LatLng; snappedTo: 'vertex' | 'grid' | 'none'; distanceMeters: number } {
  let closestVertex: LatLng | null = null;
  let minVertexDist = Infinity;

  const geom = parcel.geometry;
  const checkRing = (ring: [number, number][]) => {
    for (const pt of ring) {
      const vLat = pt[1];
      const vLng = pt[0];
      const dist = haversineDistanceMeters(targetPoint, { lat: vLat, lng: vLng });
      if (dist < minVertexDist) {
        minVertexDist = dist;
        closestVertex = { lat: vLat, lng: vLng };
      }
    }
  };

  if (geom.type === 'Polygon') {
    for (const r of geom.coordinates) checkRing(r);
  } else if (geom.type === 'MultiPolygon') {
    for (const poly of geom.coordinates) {
      for (const r of poly) checkRing(r);
    }
  }

  if (closestVertex && minVertexDist <= thresholdMeters) {
    return {
      snappedPoint: closestVertex,
      snappedTo: 'vertex',
      distanceMeters: minVertexDist,
    };
  }

  // Snap to grid in Web Mercator meters
  const [x, y] = latLonToMeters(targetPoint.lat, targetPoint.lng);
  const GRID_SIZE = gridCellSize > 0 ? gridCellSize : 2.0;
  const snappedX = Math.round(x / GRID_SIZE) * GRID_SIZE;
  const snappedY = Math.round(y / GRID_SIZE) * GRID_SIZE;
  const [gridLat, gridLng] = metersToLatLon(snappedX, snappedY);
  const gridDist = haversineDistanceMeters(targetPoint, { lat: gridLat, lng: gridLng });

  if (gridDist <= thresholdMeters) {
    return {
      snappedPoint: { lat: gridLat, lng: gridLng },
      snappedTo: 'grid',
      distanceMeters: gridDist,
    };
  }

  return {
    snappedPoint: targetPoint,
    snappedTo: 'none',
    distanceMeters: 0,
  };
}

/**
 * Computes grid line segments strictly clipped within a parcel polygon boundary.
 * Scanline ray-intersection guarantees zero lines spill outside the parcel boundary.
 */
export function computePolygonClippedGrid(
  parcel: ParcelFeature,
  cellSizeMeters: number
): {
  horizontalSegments: GridLineSegment[];
  verticalSegments: GridLineSegment[];
  widthMeters: number;
  heightMeters: number;
  origin: LatLng;
} {
  const geom = parcel.geometry;
  let ring: [number, number][] = [];
  if (geom.type === 'Polygon' && geom.coordinates?.[0]) {
    ring = geom.coordinates[0];
  } else if (geom.type === 'MultiPolygon' && geom.coordinates?.[0]?.[0]) {
    ring = geom.coordinates[0][0];
  }

  if (ring.length < 3) {
    return {
      horizontalSegments: [],
      verticalSegments: [],
      widthMeters: 0,
      heightMeters: 0,
      origin: { lat: 0, lng: 0 },
    };
  }

  // Remove duplicate closing point if present
  const cleanRing = [...ring];
  if (
    cleanRing.length > 3 &&
    cleanRing[0][0] === cleanRing[cleanRing.length - 1][0] &&
    cleanRing[0][1] === cleanRing[cleanRing.length - 1][1]
  ) {
    cleanRing.pop();
  }

  let minLat = cleanRing[0][1];
  let maxLat = cleanRing[0][1];
  let minLng = cleanRing[0][0];
  let maxLng = cleanRing[0][0];

  for (const pt of cleanRing) {
    if (pt[1] < minLat) minLat = pt[1];
    if (pt[1] > maxLat) maxLat = pt[1];
    if (pt[0] < minLng) minLng = pt[0];
    if (pt[0] > maxLng) maxLng = pt[0];
  }

  const centerLat = (minLat + maxLat) / 2.0;
  const centerLng = (minLng + maxLng) / 2.0;

  const widthMeters = haversineDistanceMeters(
    { lat: centerLat, lng: minLng },
    { lat: centerLat, lng: maxLng }
  );
  const heightMeters = haversineDistanceMeters(
    { lat: minLat, lng: centerLng },
    { lat: maxLat, lng: centerLng }
  );

  const deltaLatPerMeter = 1.0 / 111111.0;
  const deltaLngPerMeter = 1.0 / (111111.0 * Math.cos((centerLat * Math.PI) / 180.0));

  const stepLat = cellSizeMeters * deltaLatPerMeter;
  const stepLng = cellSizeMeters * deltaLngPerMeter;

  const n = cleanRing.length;
  const edges: { p1: [number, number]; p2: [number, number] }[] = [];
  for (let i = 0; i < n; i++) {
    edges.push({
      p1: cleanRing[i],
      p2: cleanRing[(i + 1) % n],
    });
  }

  const horizontalSegments: GridLineSegment[] = [];
  const verticalSegments: GridLineSegment[] = [];

  // Horizontal scan lines (constant latitude Y)
  let latIndex = 0;
  for (let y = minLat + stepLat; y < maxLat; y += stepLat) {
    const xIntersections: number[] = [];
    for (const edge of edges) {
      const y1 = edge.p1[1];
      const y2 = edge.p2[1];
      const x1 = edge.p1[0];
      const x2 = edge.p2[0];

      if ((y1 <= y && y2 > y) || (y2 <= y && y1 > y)) {
        const t = (y - y1) / (y2 - y1);
        const xInt = x1 + t * (x2 - x1);
        xIntersections.push(xInt);
      }
    }

    xIntersections.sort((a, b) => a - b);
    const isMajor = latIndex % 5 === 0;

    for (let i = 0; i < xIntersections.length - 1; i += 2) {
      horizontalSegments.push({
        p1: [y, xIntersections[i]],
        p2: [y, xIntersections[i + 1]],
        isMajor,
      });
    }
    latIndex++;
    if (latIndex > 600) break;
  }

  // Vertical scan lines (constant longitude X)
  let lngIndex = 0;
  for (let x = minLng + stepLng; x < maxLng; x += stepLng) {
    const yIntersections: number[] = [];
    for (const edge of edges) {
      const y1 = edge.p1[1];
      const y2 = edge.p2[1];
      const x1 = edge.p1[0];
      const x2 = edge.p2[0];

      if ((x1 <= x && x2 > x) || (x2 <= x && x1 > x)) {
        const t = (x - x1) / (x2 - x1);
        const yInt = y1 + t * (y2 - y1);
        yIntersections.push(yInt);
      }
    }

    yIntersections.sort((a, b) => a - b);
    const isMajor = lngIndex % 5 === 0;

    for (let i = 0; i < yIntersections.length - 1; i += 2) {
      verticalSegments.push({
        p1: [yIntersections[i], x],
        p2: [yIntersections[i + 1], x],
        isMajor,
      });
    }
    lngIndex++;
    if (lngIndex > 600) break;
  }

  return {
    horizontalSegments,
    verticalSegments,
    widthMeters,
    heightMeters,
    origin: { lat: minLat, lng: minLng },
  };
}

/**
 * Calculate centroid of parcel coordinates for auto-fit
 */
export function getParcelCentroid(parcel: ParcelFeature): LatLng {
  const geom = parcel.geometry;
  let points: [number, number][] = [];

  if (geom.type === 'Polygon' && geom.coordinates?.[0]) {
    points = geom.coordinates[0];
  } else if (geom.type === 'MultiPolygon' && geom.coordinates?.[0]?.[0]) {
    points = geom.coordinates[0][0];
  }

  if (points.length === 0) return { lat: 41.621, lng: 26.572 };

  let totalLat = 0;
  let totalLng = 0;
  for (const pt of points) {
    totalLng += pt[0];
    totalLat += pt[1];
  }

  return {
    lat: totalLat / points.length,
    lng: totalLng / points.length,
  };
}

/**
 * Calculate polygon area in square meters using Shoelace formula on Mercator projection
 */
export function calculatePolygonArea(parcel: ParcelFeature): number {
  const geom = parcel.geometry;
  let ring: [number, number][] = [];
  if (geom.type === 'Polygon' && geom.coordinates?.[0]) {
    ring = geom.coordinates[0];
  } else if (geom.type === 'MultiPolygon' && geom.coordinates?.[0]?.[0]) {
    ring = geom.coordinates[0][0];
  }

  if (ring.length < 3) return 0;

  let area = 0;
  for (let i = 0; i < ring.length - 1; i++) {
    const [x1, y1] = latLonToMeters(ring[i][1], ring[i][0]);
    const [x2, y2] = latLonToMeters(ring[i + 1][1], ring[i + 1][0]);
    area += x1 * y2 - x2 * y1;
  }
  return Math.abs(area) / 2.0;
}

/**
 * Calculates polyline length in meters from an array of [lng, lat] coordinates
 */
export function calculatePolylineLengthMeters(coords: [number, number][]): number {
  if (!coords || coords.length < 2) return 0;
  let total = 0;
  for (let i = 0; i < coords.length - 1; i++) {
    total += haversineDistanceMeters(
      { lat: coords[i][1], lng: coords[i][0] },
      { lat: coords[i + 1][1], lng: coords[i + 1][0] }
    );
  }
  return parseFloat(total.toFixed(2));
}

/**
 * Evaluates whether an asset is visible according to active layer checkboxes
 */
export function isAssetVisibleInLayers(asset: CanonicalAsset, layers: LayerVisibilityState): boolean {
  switch (asset.style.icon) {
    case 'agac':
      return layers.trees;
    case 'yapi':
      return layers.buildings;
    case 'kuyu':
    case 'su_borusu':
      return layers.water;
    case 'gunes':
    case 'elektrik_kablo':
    case 'trafo':
      return layers.electric;
    case 'sensor':
      return layers.sensors;
    case 'olcum':
      return true;
    default:
      return true;
  }
}

/**
 * Creates a brand new canonical asset with tailored technical specs
 */
export function createNewAsset(
  tip: AssetType,
  pos: LatLng,
  parcel?: ParcelFeature
): CanonicalAsset {
  const now = new Date().toISOString();
  const assetId = `asset_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const localProps = parcel ? calculateLocalMeters(pos, parcel) : { local_x_m: 0, local_y_m: 0 };

  const colorMap: Record<AssetType, string> = {
    agac: '#22c55e',
    yapi: '#b45309',
    kuyu: '#0284c7',
    sensor: '#ea580c',
    gunes: '#eab308',
    olcum: '#06b6d4',
    su_borusu: '#0284c7',
    elektrik_kablo: '#eab308',
    trafo: '#f59e0b',
  };

  const nameMap: Record<AssetType, string> = {
    agac: 'Meyve Ağacı',
    yapi: 'Çiftlik Deposu',
    kuyu: 'Derin Kuyu & Pompa İstasyonu',
    sensor: 'Toprak Nem & Hava Sensörü',
    gunes: 'Güneş Paneli Sistemi (GES)',
    olcum: 'Ölçüm Noktası',
    su_borusu: 'Sulama Boru Hattı',
    elektrik_kablo: 'Elektrik Enerji Hattı',
    trafo: 'Ana Dağıtım Trafosu & AG Panosu',
  };

  const isLinear = tip === 'su_borusu' || tip === 'elektrik_kablo';

  return {
    asset_id: assetId,
    name: nameMap[tip] || `Varlık ${tip.toUpperCase()}`,
    type: isLinear ? 'LineString' : 'Point',
    geometry: isLinear
      ? {
          type: 'LineString',
          coordinates: [
            [pos.lng, pos.lat],
            [pos.lng + 0.00015, pos.lat - 0.0001],
          ],
        }
      : {
          type: 'Point',
          coordinates: [pos.lng, pos.lat],
        },
    style: {
      color: colorMap[tip] || '#22c55e',
      icon: tip,
    },
    properties: {
      iot_connected: tip === 'sensor' || tip === 'kuyu' || tip === 'gunes' || tip === 'trafo',
      local_x_m: localProps.local_x_m,
      local_y_m: localProps.local_y_m,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: `SF-${tip.toUpperCase().substring(0, 3)}-${Math.floor(100 + Math.random() * 900)}`,
          notes: 'Saha denetimi ile dijitalleştirilmiş kayıt.',
        },
        agac: tip === 'agac' ? {
          species: 'Ceviz (Juglans regia)',
          variety: 'Chandler',
          age_years: '4',
          planting_date: '2022-03-15',
          rootstock: 'Klasik',
          row_no: '3',
          tree_no: '14',
          ndvi_score: 0.82,
        } : undefined,
        solar: tip === 'gunes' ? {
          current_power_kw: 24.6,
          daily_yield_kwh: 142.8,
          peak_power_kwp: 30.0,
          inverter_efficiency_pct: 98.4,
          panel_temperature_c: 34.2,
          irradiance_w_m2: 845,
          inverter_status: 'sebeke_bagli',
          grid_voltage_v: 382,
          total_energy_mwh: 18.4,
        } : undefined,
        well_pump: tip === 'kuyu' ? {
          well_depth_m: 140,
          static_water_level_m: 48.5,
          dynamic_water_level_m: 64.2,
          flow_rate_m3_h: 46.5,
          daily_volume_m3: 312.0,
          line_pressure_bar: 4.8,
          motor_power_kw: 15.0,
          motor_current_a: 28.6,
          motor_voltage_v: 380,
          motor_status: 'calisiyor',
          dry_run_protection_ok: true,
        } : undefined,
        electric_infra: (tip === 'elektrik_kablo' || tip === 'trafo') ? {
          transformer_capacity_kva: 160,
          primary_voltage_kv: 34.5,
          secondary_voltage_v: 380,
          active_load_kw: tip === 'trafo' ? 42.4 : 28.6,
          power_factor: 0.97,
          oil_temperature_c: tip === 'trafo' ? 46.5 : 32.0,
          cable_spec: tip === 'trafo' ? '3x35+16 mm² XLPE' : '3x35+16 mm² NYY Yeraltı Zırhlı',
          line_length_m: tip === 'elektrik_kablo' ? 68.4 : undefined,
          status: 'aktif',
        } : undefined,
        water_infra: tip === 'su_borusu' ? {
          pipe_spec: 'Ø90 mm PN10 HDPE 100',
          nominal_diameter_mm: 90,
          line_pressure_bar: 3.8,
          flow_velocity_m_s: 1.45,
          valve_status: 'acik',
          filter_dp_bar: 0.25,
          line_length_m: 54.2,
          target_zone: 'Zone 1 Damla Sulama',
        } : undefined,
        saglik: tip === 'agac' ? {
          disease_name: 'Bulunmuyor',
          symptoms: 'Yaprak gelişimi sağlıklı',
          severity: 'Düşük',
          treatment_plan: 'Rutin mevsimsel besleme',
        } : undefined,
        iot: tip === 'sensor' ? {
          soil_moisture_pct: 24.5,
          soil_moisture_deep_pct: 29.8,
          trunk_temperature_c: 21.2,
          air_temperature_c: 23.4,
          air_humidity_pct: 58,
          soil_ph: 6.8,
          soil_ec: 1.2,
          battery_pct: 94,
          signal_dbm: -68,
          last_seen_at: now,
        } : (tip === 'kuyu' || tip === 'gunes' || tip === 'trafo') ? {
          air_temperature_c: 24.0,
          battery_pct: 98,
          last_seen_at: now,
        } : undefined,
        bakim: tip === 'agac' ? {
          last_irrigation_at: new Date(Date.now() - 86400000 * 2).toISOString(),
          last_fertilization_at: new Date(Date.now() - 86400000 * 14).toISOString(),
          last_pruning_at: '2026-02-10',
          last_spray_at: '2026-03-01',
        } : undefined,
        uretim: tip === 'agac' ? {
          last_yield_kg: '45',
          expected_yield_kg: '60',
          fruit_count_est: '280',
        } : undefined,
        alarm: tip === 'sensor' ? {
          soil_moisture_min: 18,
          soil_moisture_max: 42,
          air_temperature_min: 2,
          air_temperature_max: 38,
        } : undefined,
      },
      meta: {
        asset_id: assetId,
        geometry_type: isLinear ? 'LineString' : 'Point',
        asset_type: tip === 'agac' ? 'living' : 'non_living',
        category: tip,
        version: 1,
      },
      timestamps: {
        created_at: now,
        updated_at: now,
        last_operation: 'asset_created',
        timezone_offset_min: (new Date().getTimezoneOffset() * -1).toString(),
        timezone_name: 'TRT',
      },
      audit_log: [
        {
          at: now,
          event: 'asset_created_via_smartfarm_xr',
          user: 'operator',
        },
      ],
    },
  };
}
