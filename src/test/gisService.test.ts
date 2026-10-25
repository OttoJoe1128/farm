import { describe, it, expect } from 'vitest';
import {
  latLonToMeters,
  metersToLatLon,
  haversineDistanceMeters,
  isPointInPolygon,
  calculateLocalMeters,
  snapToParcelOrGrid,
  computePolygonClippedGrid,
  buildParcelGridCellSizes,
  findParcelContainingPoint,
  getParcelId,
  createNewAsset,
  getParcelDimensionMeters,
  MIN_GRID_CELL_METERS,
} from '../services/gisService';
import { EDIRNE_PARCEL, MILAS_PARCEL } from '../services/sampleData';

describe('GIS & Spatial Geometry Service Tests', () => {
  it('should accurately convert LatLng to Web Mercator meters and back', () => {
    const lat = 41.62103;
    const lng = 26.57218;

    const [x, y] = latLonToMeters(lat, lng);
    expect(x).toBeGreaterThan(0);
    expect(y).toBeGreaterThan(0);

    const [roundLat, roundLng] = metersToLatLon(x, y);
    expect(Math.abs(roundLat - lat)).toBeLessThan(0.00001);
    expect(Math.abs(roundLng - lng)).toBeLessThan(0.00001);
  });

  it('should correctly calculate distance using Haversine formula', () => {
    const p1 = { lat: 41.62103, lng: 26.57218 };
    const p2 = { lat: 41.62103, lng: 26.57218 };
    expect(haversineDistanceMeters(p1, p2)).toBe(0);

    // 0.001 deg latitude is roughly 111 meters
    const p3 = { lat: 41.62203, lng: 26.57218 };
    const dist = haversineDistanceMeters(p1, p3);
    expect(dist).toBeGreaterThan(100);
    expect(dist).toBeLessThan(120);
  });

  it('should identify points strictly inside the parcel boundary', () => {
    // Point inside Edirne Bosna parcel
    const insidePoint = { lat: 41.62085, lng: 26.57165 };
    expect(isPointInPolygon(insidePoint, EDIRNE_PARCEL)).toBe(true);

    // Point far outside
    const outsidePoint = { lat: 41.63000, lng: 26.58000 };
    expect(isPointInPolygon(outsidePoint, EDIRNE_PARCEL)).toBe(false);
  });

  it('should compute local meter coordinates relative to origin vertex', () => {
    const originVertex = {
      lat: EDIRNE_PARCEL.geometry.coordinates[0][0][1],
      lng: EDIRNE_PARCEL.geometry.coordinates[0][0][0],
    };
    const localAtOrigin = calculateLocalMeters(originVertex, EDIRNE_PARCEL);
    expect(localAtOrigin.local_x_m).toBe(0);
    expect(localAtOrigin.local_y_m).toBe(0);
  });

  it('should snap to nearest parcel vertex when within threshold', () => {
    const vertex = {
      lat: EDIRNE_PARCEL.geometry.coordinates[0][0][1],
      lng: EDIRNE_PARCEL.geometry.coordinates[0][0][0],
    };
    // Offset slightly (~0.3m)
    const clickPoint = { lat: vertex.lat + 0.000003, lng: vertex.lng + 0.000003 };
    const snapResult = snapToParcelOrGrid(clickPoint, EDIRNE_PARCEL, 2.0);

    expect(snapResult.snappedTo).toBe('vertex');
    expect(snapResult.snappedPoint.lat).toBeCloseTo(vertex.lat, 5);
    expect(snapResult.snappedPoint.lng).toBeCloseTo(vertex.lng, 5);
  });

  it('should compute polygon-clipped grid segments strictly inside parcel boundary', () => {
    const { horizontalSegments, verticalSegments, widthMeters, heightMeters } = computePolygonClippedGrid(
      EDIRNE_PARCEL,
      5.0
    );

    expect(widthMeters).toBeGreaterThan(50);
    expect(heightMeters).toBeGreaterThan(40);
    expect(horizontalSegments.length).toBeGreaterThan(0);
    expect(verticalSegments.length).toBeGreaterThan(0);

    // Verify midpoints of segments are inside parcel
    for (const seg of horizontalSegments.slice(0, 5)) {
      const midPoint = {
        lat: seg.p1[0],
        lng: (seg.p1[1] + seg.p2[1]) / 2,
      };
      expect(isPointInPolygon(midPoint, EDIRNE_PARCEL)).toBe(true);
    }
  });

  it('should start parcel grid sizes at 0.5 m and stay within parcel dimensions', () => {
    const { widthMeters, heightMeters } = getParcelDimensionMeters(EDIRNE_PARCEL);
    const sizes = buildParcelGridCellSizes(widthMeters, heightMeters);
    expect(sizes[0]).toBe(MIN_GRID_CELL_METERS);
    expect(sizes).toContain(1);
    const shorter = Math.min(widthMeters, heightMeters);
    for (const size of sizes) {
      if (size !== MIN_GRID_CELL_METERS) {
        expect(size).toBeLessThanOrEqual(shorter);
      }
    }
  });

  it('should compute 0.5 m clipped grid inside the parcel', () => {
    const { horizontalSegments, verticalSegments } = computePolygonClippedGrid(EDIRNE_PARCEL, MIN_GRID_CELL_METERS);
    expect(horizontalSegments.length).toBeGreaterThan(0);
    expect(verticalSegments.length).toBeGreaterThan(0);
  });

  it('should resolve the parcel that contains a click', () => {
    const insideEdirne = { lat: 41.62085, lng: 26.57165 };
    expect(findParcelContainingPoint(insideEdirne, [EDIRNE_PARCEL, MILAS_PARCEL])?.properties.ParselNo).toBe('835');
    const outside = { lat: 41.63, lng: 26.58 };
    expect(findParcelContainingPoint(outside, [EDIRNE_PARCEL, MILAS_PARCEL])).toBeNull();
  });

  it('should bind new assets to the host parcel via parcel_id', () => {
    const pos = { lat: 41.62085, lng: 26.57165 };
    const asset = createNewAsset('agac', pos, EDIRNE_PARCEL);
    expect(asset.parcel_id).toBe(getParcelId(EDIRNE_PARCEL));
    expect(asset.parcel_id).not.toBe(getParcelId(MILAS_PARCEL));
    expect(createNewAsset('agac', pos).parcel_id).toBeUndefined();
  });
});

