import { ParcelFeature } from '../types';
import { getParcelId, geometryFingerprint } from './gisService';

export interface ParcelImportResult {
  /** Birleştirilmiş tam parsel listesi (hata durumunda mevcut liste aynen döner). */
  parcels: ParcelFeature[];
  /** Haritada odaklanılacak ilk eklenen/güncellenen parsel. */
  focus: ParcelFeature | null;
  added: number;
  updated: number;
  skipped: number;
  errors: string[];
  warnings: string[];
}

type Position = [number, number];

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function isPosition(value: unknown): value is Position {
  return Array.isArray(value) && value.length >= 2 && isFiniteNumber(value[0]) && isFiniteNumber(value[1]);
}

function isValidRing(ring: unknown): ring is Position[] {
  return Array.isArray(ring) && ring.length >= 4 && ring.every(isPosition);
}

function isValidPolygon(poly: unknown): poly is Position[][] {
  return Array.isArray(poly) && poly.length >= 1 && poly.every(isValidRing);
}

function collectPositions(geometry: any): Position[] {
  const out: Position[] = [];
  const rings: Position[][] =
    geometry.type === 'Polygon' ? geometry.coordinates : (geometry.coordinates as Position[][][]).flat();
  for (const ring of rings) for (const pos of ring) out.push(pos);
  return out;
}

type GeometryProblem = 'invalid' | 'projected' | null;

function checkGeometry(geometry: any): GeometryProblem {
  if (!geometry || (geometry.type !== 'Polygon' && geometry.type !== 'MultiPolygon')) return 'invalid';
  const structureOk =
    geometry.type === 'Polygon'
      ? isValidPolygon(geometry.coordinates)
      : Array.isArray(geometry.coordinates) && geometry.coordinates.length >= 1 && geometry.coordinates.every(isValidPolygon);
  if (!structureOk) return 'invalid';
  const outOfRange = collectPositions(geometry).some(([lon, lat]) => Math.abs(lon) > 180 || Math.abs(lat) > 90);
  return outOfRange ? 'projected' : null;
}

function extractFeatures(json: any): any[] | null {
  if (!json || typeof json !== 'object') return null;
  if (Array.isArray(json.features)) return json.features;
  if (json.type === 'Feature' && json.geometry) return [json];
  if (json.type === 'Polygon' || json.type === 'MultiPolygon') {
    return [{ type: 'Feature', geometry: json, properties: {} }];
  }
  return null;
}

/**
 * GeoJSON metnini doğrular, parsel kimliklerini (`parcel_id`) yazar ve mevcut listeyle birleştirir.
 * - Aynı kimlik + aynı geometri: mevcut parsel güncellenir (çoğalmaz).
 * - Aynı kimlik + farklı geometri: yeni parsel `-2`, `-3`... son ekiyle ayrı kimlik alır.
 */
export function importParcelsFromText(text: string, existing: ParcelFeature[]): ParcelImportResult {
  const result: ParcelImportResult = {
    parcels: existing,
    focus: null,
    added: 0,
    updated: 0,
    skipped: 0,
    errors: [],
    warnings: [],
  };

  const content = text.replace(/^\uFEFF/, '').trim();
  if (content === '') {
    result.errors.push('Dosya boş.');
    return result;
  }
  if (content.startsWith('<')) {
    result.errors.push('KML/XML dosyaları henüz desteklenmiyor. Dosyayı GeoJSON olarak dışa aktarıp (ör. QGIS) yükleyin.');
    return result;
  }

  let json: any;
  try {
    json = JSON.parse(content);
  } catch {
    result.errors.push('Dosya geçerli bir JSON/GeoJSON değil.');
    return result;
  }

  const rawFeatures = extractFeatures(json);
  if (rawFeatures === null) {
    result.errors.push('Dosyada GeoJSON parsel (Feature, FeatureCollection, Polygon veya MultiPolygon) bulunamadı.');
    return result;
  }

  let projectedCount = 0;
  const candidates: ParcelFeature[] = [];
  rawFeatures.forEach((raw) => {
    const problem = checkGeometry(raw?.geometry);
    if (problem === 'projected') projectedCount++;
    if (problem !== null) {
      result.skipped++;
      return;
    }
    const properties = raw.properties && typeof raw.properties === 'object' ? { ...raw.properties } : {};
    candidates.push({ type: 'Feature', geometry: raw.geometry, properties });
  });

  if (projectedCount > 0) {
    result.errors.push(
      `${projectedCount} parselin koordinatları derece (WGS84 / EPSG:4326) değil, metre cinsinden projeksiyonlu görünüyor. ` +
        'Dosyayı EPSG:4326 olarak dışa aktarıp yeniden yükleyin.'
    );
  }
  if (candidates.length === 0) {
    if (result.errors.length === 0) {
      result.errors.push('Dosyada geçerli Polygon/MultiPolygon parsel geometrisi bulunamadı.');
    }
    return result;
  }
  if (result.skipped > projectedCount) {
    result.warnings.push(`${result.skipped - projectedCount} kayıt geçersiz geometri nedeniyle atlandı.`);
  }

  const merged: ParcelFeature[] = [...existing];
  const addedList: ParcelFeature[] = [];
  const touched: ParcelFeature[] = [];

  candidates.forEach((candidate, index) => {
    if (!candidate.properties.name && !candidate.properties.ParselNo) {
      candidate.properties.name = `Yüklenen Parsel ${index + 1}`;
    }
    const baseId = getParcelId(candidate) as string;
    const fingerprint = geometryFingerprint(candidate);
    let id = baseId;
    let suffix = 1;
    for (;;) {
      const clashIndex = merged.findIndex((p) => getParcelId(p) === id);
      const clashInAdded = addedList.findIndex((p) => getParcelId(p) === id);
      if (clashIndex === -1 && clashInAdded === -1) {
        const stamped: ParcelFeature = { ...candidate, properties: { ...candidate.properties, parcel_id: id } };
        addedList.push(stamped);
        touched.push(stamped);
        result.added++;
        return;
      }
      const clashing = clashIndex !== -1 ? merged[clashIndex] : addedList[clashInAdded];
      if (geometryFingerprint(clashing) === fingerprint) {
        const stamped: ParcelFeature = { ...candidate, properties: { ...candidate.properties, parcel_id: id } };
        if (clashIndex !== -1) merged[clashIndex] = stamped;
        else addedList[clashInAdded] = stamped;
        touched.push(stamped);
        result.updated++;
        return;
      }
      suffix++;
      id = `${baseId}-${suffix}`;
    }
  });

  result.parcels = [...addedList, ...merged];
  result.focus = touched[0] ?? null;
  return result;
}

/** Kullanıcıya gösterilecek özet mesaj. */
export function describeImportResult(result: ParcelImportResult): string {
  const lines: string[] = [];
  if (result.focus) {
    const parts: string[] = [];
    if (result.added > 0) parts.push(`${result.added} yeni parsel eklendi`);
    if (result.updated > 0) parts.push(`${result.updated} mevcut parsel güncellendi`);
    lines.push(parts.join(', ') + '.');
  }
  lines.push(...result.errors, ...result.warnings);
  return lines.join('\n');
}
