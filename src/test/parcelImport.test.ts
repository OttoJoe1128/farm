import { describe, it, expect } from 'vitest';
import { importParcelsFromText, describeImportResult } from '../services/parcelImport';
import { areSameParcel, getParcelId, getParcelLabel } from '../services/gisService';
import { buildBackup, parseBackup } from '../services/persistence';
import { EDIRNE_PARCEL, MILAS_PARCEL, INITIAL_ASSETS, INITIAL_WORK_ORDERS } from '../services/sampleData';

const square = (lon: number, lat: number, size = 0.0005) => [
  [
    [lon, lat],
    [lon + size, lat],
    [lon + size, lat + size],
    [lon, lat + size],
    [lon, lat],
  ],
];

const collection = (features: unknown[]) => JSON.stringify({ type: 'FeatureCollection', features });

const tkgmFeature = (lon: number, lat: number, ada: string, no: string) => ({
  type: 'Feature',
  properties: { ParselNo: no, Ada: ada, Il: 'Edirne', Ilce: 'Merkez', Alan: '1.000 m²', Nitelik: 'Tarla' },
  geometry: { type: 'Polygon', coordinates: square(lon, lat) },
});

const namedFeature = (lon: number, lat: number, name: string) => ({
  type: 'Feature',
  properties: { name, area_type: 'tarla', owner: 'Test' },
  geometry: { type: 'Polygon', coordinates: square(lon, lat) },
});

describe('GeoJSON parsel yükleme', () => {
  it('TKGM alanlı parseli kabul eder ve parcel_id yazar', () => {
    const result = importParcelsFromText(collection([tkgmFeature(27.0, 41.0, '55', '9')]), []);
    expect(result.errors).toEqual([]);
    expect(result.added).toBe(1);
    expect(result.parcels[0].properties.parcel_id).toBe('55/9');
    expect(result.focus).toBe(result.parcels[0]);
  });

  it('ParselNo olmayan parsellere ayrı kimlik ve ad verir (hepsi 0/0 olmaz)', () => {
    const text = collection([
      namedFeature(28.97, 41.0, 'Parsel A'),
      namedFeature(29.1, 41.1, 'Parsel B'),
      namedFeature(29.2, 41.2, 'Parsel C'),
    ]);
    const result = importParcelsFromText(text, []);
    const ids = result.parcels.map((p) => getParcelId(p));
    expect(new Set(ids).size).toBe(3);
    expect(ids.every((id) => id?.startsWith('geo-'))).toBe(true);
    expect(areSameParcel(result.parcels[0], result.parcels[1])).toBe(false);
    expect(result.parcels.map(getParcelLabel).sort()).toEqual(['Parsel A', 'Parsel B', 'Parsel C']);
  });

  it('adı ve ParselNo\'su olmayan parsele okunur bir ad verir', () => {
    const feature = { type: 'Feature', properties: {}, geometry: { type: 'Polygon', coordinates: square(30, 40) } };
    const result = importParcelsFromText(collection([feature]), []);
    expect(getParcelLabel(result.parcels[0])).toBe('Yüklenen Parsel 1');
  });

  it('aynı dosyayı tekrar yüklemek parselleri çoğaltmaz, günceller', () => {
    const text = collection([tkgmFeature(27.0, 41.0, '55', '9'), namedFeature(28.0, 41.5, 'X')]);
    const first = importParcelsFromText(text, [EDIRNE_PARCEL, MILAS_PARCEL]);
    expect(first.added).toBe(2);
    expect(first.parcels).toHaveLength(4);
    const second = importParcelsFromText(text, first.parcels);
    expect(second.added).toBe(0);
    expect(second.updated).toBe(2);
    expect(second.parcels).toHaveLength(4);
  });

  it('aynı Ada/ParselNo ama farklı geometri: ayrı kimlik alır, tekrar yüklemede de çoğalmaz', () => {
    const a = collection([tkgmFeature(27.0, 41.0, '55', '9')]);
    const b = collection([tkgmFeature(33.0, 38.0, '55', '9')]);
    const step1 = importParcelsFromText(a, []);
    const step2 = importParcelsFromText(b, step1.parcels);
    expect(step2.added).toBe(1);
    expect(step2.parcels.map((p) => getParcelId(p)).sort()).toEqual(['55/9', '55/9-2']);
    const step3 = importParcelsFromText(b, step2.parcels);
    expect(step3.added).toBe(0);
    expect(step3.updated).toBe(1);
    expect(step3.parcels).toHaveLength(2);
  });

  it('örnek parselle aynı geometriyi yüklemek örnek parseli günceller', () => {
    const text = JSON.stringify({ type: 'FeatureCollection', features: [EDIRNE_PARCEL] });
    const result = importParcelsFromText(text, [EDIRNE_PARCEL, MILAS_PARCEL]);
    expect(result.added).toBe(0);
    expect(result.updated).toBe(1);
    expect(result.parcels).toHaveLength(2);
  });

  it('tek Feature ve çıplak Polygon geometrisi kabul edilir', () => {
    const single = importParcelsFromText(JSON.stringify(tkgmFeature(27, 41, '1', '2')), []);
    expect(single.added).toBe(1);
    const bare = importParcelsFromText(JSON.stringify({ type: 'Polygon', coordinates: square(27, 41) }), []);
    expect(bare.added).toBe(1);
  });

  it('MultiPolygon kabul edilir', () => {
    const feature = {
      type: 'Feature',
      properties: { name: 'MP' },
      geometry: { type: 'MultiPolygon', coordinates: [square(27, 41), square(27.1, 41.1)] },
    };
    const result = importParcelsFromText(collection([feature]), []);
    expect(result.added).toBe(1);
  });

  it('projeksiyonlu (metre) koordinatları anlaşılır hatayla reddeder, liste değişmez', () => {
    const projected = {
      type: 'Feature',
      properties: { ParselNo: '1' },
      geometry: {
        type: 'Polygon',
        coordinates: [[[500000, 4400000], [500100, 4400000], [500100, 4400100], [500000, 4400100], [500000, 4400000]]],
      },
    };
    const existing = [EDIRNE_PARCEL];
    const result = importParcelsFromText(collection([projected]), existing);
    expect(result.focus).toBeNull();
    expect(result.parcels).toBe(existing);
    expect(result.errors.join(' ')).toContain('EPSG:4326');
  });

  it('geçerli ve geçersiz kayıtları birlikte işler, geçersizleri uyarıyla atlar', () => {
    const point = { type: 'Feature', properties: {}, geometry: { type: 'Point', coordinates: [27, 41] } };
    const result = importParcelsFromText(collection([tkgmFeature(27, 41, '3', '4'), point]), []);
    expect(result.added).toBe(1);
    expect(result.skipped).toBe(1);
    expect(result.warnings.join(' ')).toContain('atlandı');
  });

  it('halkası 4 noktadan az olan ya da sayı olmayan koordinatlı geometriyi reddeder', () => {
    const tooShort = { type: 'Feature', properties: {}, geometry: { type: 'Polygon', coordinates: [[[27, 41], [27.1, 41], [27, 41]]] } };
    const nan = { type: 'Feature', properties: {}, geometry: { type: 'Polygon', coordinates: [[['a', 'b'], [1, 2], [3, 4], ['a', 'b']]] } };
    const result = importParcelsFromText(collection([tooShort, nan]), []);
    expect(result.focus).toBeNull();
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('KML/XML, boş, bozuk ve ilgisiz içerik için net hata verir', () => {
    expect(importParcelsFromText('<?xml version="1.0"?><kml></kml>', []).errors[0]).toContain('KML');
    expect(importParcelsFromText('   ', []).errors[0]).toContain('boş');
    expect(importParcelsFromText('{bozuk', []).errors[0]).toContain('JSON');
    expect(importParcelsFromText(JSON.stringify({ merhaba: 1 }), []).errors[0]).toContain('bulunamadı');
  });

  it('BOM ile başlayan dosyayı okur', () => {
    const result = importParcelsFromText('\uFEFF' + collection([tkgmFeature(27, 41, '7', '8')]), []);
    expect(result.added).toBe(1);
  });

  it('kullanıcı mesajı özetini üretir', () => {
    const result = importParcelsFromText(collection([tkgmFeature(27, 41, '7', '8')]), []);
    expect(describeImportResult(result)).toContain('1 yeni parsel eklendi');
  });
});

describe('Parsel kimliği ve etiket', () => {
  it('örnek TKGM parsellerinin kimliği değişmedi (Ada/ParselNo)', () => {
    expect(getParcelId(EDIRNE_PARCEL)).toBe('103/835');
    expect(getParcelId(MILAS_PARCEL)).toBe('204/1073');
    expect(areSameParcel(EDIRNE_PARCEL, MILAS_PARCEL)).toBe(false);
    expect(areSameParcel(EDIRNE_PARCEL, EDIRNE_PARCEL)).toBe(true);
  });

  it('"Parsel undefined" üretmez', () => {
    expect(getParcelLabel({ type: 'Feature', geometry: EDIRNE_PARCEL.geometry, properties: {} })).toBe('Adsiz Parsel');
    expect(getParcelLabel(null)).toBe('-');
  });
});

describe('Yedekleme', () => {
  it('yedek oluşturup geri okur', () => {
    const state = { assets: INITIAL_ASSETS, workOrders: INITIAL_WORK_ORDERS, parcels: [EDIRNE_PARCEL, MILAS_PARCEL] };
    const restored = parseBackup(buildBackup(state));
    expect(restored).not.toBeNull();
    expect(restored?.parcels).toHaveLength(2);
    expect(restored?.assets).toHaveLength(INITIAL_ASSETS.length);
    expect(restored?.workOrders).toHaveLength(INITIAL_WORK_ORDERS.length);
  });

  it('yedek olmayan dosyayı (GeoJSON) yedek sanmaz', () => {
    expect(parseBackup(collection([tkgmFeature(27, 41, '1', '1')]))).toBeNull();
    expect(parseBackup('bozuk')).toBeNull();
    expect(parseBackup(JSON.stringify({ smartfarm_backup: 1, assets: [] }))).toBeNull();
  });
});
