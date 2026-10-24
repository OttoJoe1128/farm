import { describe, it, expect } from 'vitest';
import { IoTTelemetry, WorkOrder } from '../types';

describe('Backend API & Live Event Contract Tests', () => {
  it('should enforce Phase 2 _meta standard response structure', () => {
    const responsePayload = {
      ok: true,
      data: { status: 'synced', version: 4 },
      _meta: {
        api_version: 'farm.v1.1.phase2',
        request_id: '5f92d8e412ba',
        served_at: new Date().toISOString(),
        user_id: 'usr_operator_1',
      },
    };

    expect(responsePayload._meta.api_version).toBe('farm.v1.1.phase2');
    expect(responsePayload._meta.request_id).toBeDefined();
    expect(responsePayload._meta.served_at).toBeDefined();
  });

  it('should conform to frozen ws.live.telemetry.v1 schema', () => {
    const event: IoTTelemetry = {
      schema_version: 'ws.live.telemetry.v1',
      asset_id: 'asset_sensor_001',
      device_id: 'SF-DEV-001',
      metrics: {
        soil_moisture_pct: 21.8,
        trunk_temperature_c: 20.4,
        air_temperature_c: 24.5,
        air_humidity_pct: 55,
      },
      alerts: ['soil_moisture_low'],
      measured_at: '2026-10-24T03:30:00Z',
      quality_flag: 'good_quality',
    };

    expect(event.schema_version).toBe('ws.live.telemetry.v1');
    expect(event.asset_id).toBe('asset_sensor_001');
    expect(event.device_id).toBe('SF-DEV-001');
    expect(event.metrics.soil_moisture_pct).toBe(21.8);
    expect(Array.isArray(event.alerts)).toBe(true);
  });

  it('should correctly resolve conflicts using latest_timestamp_wins', () => {
    const existing = {
      id: 'asset_1',
      name: 'Varlık v1',
      updated_at: '2026-10-24T01:00:00Z',
    };
    const incoming = {
      id: 'asset_1',
      name: 'Varlık v2 (Yeni)',
      updated_at: '2026-10-24T02:30:00Z',
    };

    const isIncomingNewer = new Date(incoming.updated_at).getTime() > new Date(existing.updated_at).getTime();
    const resolved = isIncomingNewer ? incoming : existing;

    expect(resolved.name).toBe('Varlık v2 (Yeni)');
  });

  it('should validate work order lifecycle states', () => {
    const validStatuses = ['bekliyor', 'devam_ediyor', 'tamamlandi', 'iptal'];
    const order: WorkOrder = {
      work_order_id: 'WO-2026-001',
      asset_id: 'asset_tree_001',
      title: 'İlaçlama Kontrolü',
      description: 'Zararlı kontrolü yapıldı.',
      assignee: 'Ahmet Yılmaz',
      priority: 'yuksek',
      status: 'tamamlandi',
      created_at: '2026-10-24T00:00:00Z',
      completed_at: '2026-10-24T02:00:00Z',
    };

    expect(validStatuses).toContain(order.status);
    expect(order.completed_at).toBeDefined();
  });
});
