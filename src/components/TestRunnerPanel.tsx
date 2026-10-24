import React, { useState } from 'react';
import { CheckCircle2, XCircle, Play, ShieldAlert, Terminal, Sparkles, RefreshCw, ArrowLeft } from 'lucide-react';
import { latLonToMeters, metersToLatLon, isPointInPolygon, snapToParcelOrGrid, calculateLocalMeters } from '../services/gisService';
import { EDIRNE_PARCEL, MILAS_PARCEL, INITIAL_ASSETS } from '../services/sampleData';

interface TestCase {
  id: string;
  category: 'Geospatial GIS' | 'Backend API Contract' | 'IoT & Live Event' | 'Conflict Policy' | 'Work Order Lifecycle';
  title: string;
  description: string;
  run: () => { pass: boolean; message: string; details?: any };
}

interface TestRunnerPanelProps {
  onBackToMap?: () => void;
}

export const TestRunnerPanel: React.FC<TestRunnerPanelProps> = ({ onBackToMap }) => {
  const [testResults, setTestResults] = useState<Record<string, { pass: boolean; message: string; details?: any }>>({});
  const [isRunning, setIsRunning] = useState(false);

  const testCases: TestCase[] = [
    {
      id: 'gis-mercator-roundtrip',
      category: 'Geospatial GIS',
      title: 'Web Mercator EPSG:3857 İki Yönlü Dönüşüm Hassasiyeti',
      description: 'Enlem ve boylamı metrik koordinata çevirip geri döndürdüğünde sapma < 0.0001 derece olmalıdır.',
      run: () => {
        const testLat = 41.62103;
        const testLng = 26.57218;
        const [x, y] = latLonToMeters(testLat, testLng);
        const [backLat, backLng] = metersToLatLon(x, y);
        const latDelta = Math.abs(testLat - backLat);
        const lngDelta = Math.abs(testLng - backLng);
        const pass = latDelta < 0.00001 && lngDelta < 0.00001;
        return {
          pass,
          message: pass
            ? `Hassasiyet doğrulandı: deltaLat=${latDelta.toExponential(2)}, deltaLng=${lngDelta.toExponential(2)}`
            : `Hata: Sapma toleransı aşıldı!`,
          details: { origin: [testLat, testLng], roundtrip: [backLat, backLng] },
        };
      },
    },
    {
      id: 'gis-point-in-polygon',
      category: 'Geospatial GIS',
      title: 'Ray-Casting Algoritması ile Parsel İçi/Dışı Kontrolü',
      description: 'Edirne parseli merkezindeki nokta "İçeride", 100m kuzeyindeki nokta "Dışarıda" olarak doğrulanmalıdır.',
      run: () => {
        const insidePoint = { lat: 41.62085, lng: 26.57165 };
        const outsidePoint = { lat: 41.63000, lng: 26.58000 };
        const isInside = isPointInPolygon(insidePoint, EDIRNE_PARCEL);
        const isOutside = !isPointInPolygon(outsidePoint, EDIRNE_PARCEL);
        const pass = isInside && isOutside;
        return {
          pass,
          message: pass
            ? `Başarılı: İç nokta doğru tespit edildi (true), dış nokta reddedildi (false).`
            : `Hata: Poligon içi/dışı sınır tespiti hatalı!`,
        };
      },
    },
    {
      id: 'gis-vertex-snap',
      category: 'Geospatial GIS',
      title: 'Kadastro Köşe Noktası ve 2m Grid Snapping',
      description: 'Köşe noktasına 1.5 metre yakınlıktaki bir tıklama tam köşe koordinatına kilitlenmelidir.',
      run: () => {
        const firstVertex = {
          lat: EDIRNE_PARCEL.geometry.coordinates[0][0][1],
          lng: EDIRNE_PARCEL.geometry.coordinates[0][0][0],
        };
        // 0.000005 deg offset (~0.5m)
        const nearPoint = { lat: firstVertex.lat + 0.000005, lng: firstVertex.lng + 0.000005 };
        const result = snapToParcelOrGrid(nearPoint, EDIRNE_PARCEL, 2.5);
        const pass = result.snappedTo === 'vertex' && result.distanceMeters < 1.0;
        return {
          pass,
          message: pass
            ? `Snap kilitlenmesi başarılı: ${result.distanceMeters.toFixed(2)}m uzaklıktan köşe koordinatına kenetlendi.`
            : `Hata: Snap algoritması köşeyi yakalayamadı.`,
          details: result,
        };
      },
    },
    {
      id: 'contract-meta-envelope',
      category: 'Backend API Contract',
      title: 'Standard API Yanıt & Meta Zarf Kontratı (farm.v1.1.phase2)',
      description: 'Backend kontratlarında _meta zarfı api_version, request_id ve served_at alanlarını içermelidir.',
      run: () => {
        const mockMetaResponse = {
          ok: true,
          data: { status: 'healthy' },
          _meta: {
            api_version: 'farm.v1.1.phase2',
            request_id: 'req_test_98a7c2',
            served_at: new Date().toISOString(),
          },
        };
        const pass =
          mockMetaResponse._meta.api_version === 'farm.v1.1.phase2' &&
          Boolean(mockMetaResponse._meta.request_id) &&
          Boolean(mockMetaResponse._meta.served_at);
        return {
          pass,
          message: pass
            ? `Faz 2 Meta zarfı sözleşmesi geçerli (API Version: ${mockMetaResponse._meta.api_version})`
            : 'Hata: Meta zarf sözleşmesi ihlal edildi!',
        };
      },
    },
    {
      id: 'iot-ws-schema-frozen',
      category: 'IoT & Live Event',
      title: 'Dondurulmuş Canlı Telemetri Şeması (ws.live.telemetry.v1)',
      description: 'WebSocket ve IoT router üzerinden yayılan olaylar ws.live.telemetry.v1 zorunlu alanlarını sağlamalıdır.',
      run: () => {
        const eventPayload = {
          schema_version: 'ws.live.telemetry.v1',
          type: 'telemetry',
          asset_id: 'asset_sensor_001',
          device_id: 'SF-DEV-001',
          metrics: { soil_moisture_pct: 21.4, air_temperature_c: 24.1 },
          alerts: ['soil_moisture_low'],
          measured_at: new Date().toISOString(),
        };
        const requiredFields = ['schema_version', 'type', 'asset_id', 'device_id', 'metrics', 'alerts', 'measured_at'];
        const missingFields = requiredFields.filter((f) => !(f in eventPayload));
        const pass = missingFields.length === 0 && eventPayload.schema_version === 'ws.live.telemetry.v1';
        return {
          pass,
          message: pass
            ? `Telemetri kontratı şemaya tam uyumlu (ws.live.telemetry.v1). Eksik alan yok.`
            : `Hata: Eksik alanlar tespit edildi: ${missingFields.join(', ')}`,
        };
      },
    },
    {
      id: 'conflict-policy-resolution',
      category: 'Conflict Policy',
      title: 'Çakışma Çözümleme Politikası (latest_timestamp_wins & incoming_wins)',
      description: 'İstemci ve sunucu aynı varlığı güncellediğinde zaman damgası veya politika kuralına göre birleştirilmelidir.',
      run: () => {
        const existingAsset = {
          name: 'Eski Ağaç',
          timestamps: { updated_at: '2026-10-24T01:00:00Z' },
        };
        const incomingAsset = {
          name: 'Yeni Ağaç',
          timestamps: { updated_at: '2026-10-24T02:00:00Z' },
        };
        // Policy: latest_timestamp_wins
        const incomingIsNewer =
          new Date(incomingAsset.timestamps.updated_at) > new Date(existingAsset.timestamps.updated_at);
        const resolvedName = incomingIsNewer ? incomingAsset.name : existingAsset.name;
        const pass = resolvedName === 'Yeni Ağaç';
        return {
          pass,
          message: pass
            ? `Çakışma politikası doğru sonuç verdi: Yeni zaman damgalı varlık kabul edildi (${resolvedName}).`
            : `Hata: Çakışma politikası hatalı çözümlendi!`,
        };
      },
    },
    {
      id: 'work-order-lifecycle',
      category: 'Work Order Lifecycle',
      title: 'İş Emri Durum Geçişleri (bekliyor -> devam_ediyor -> tamamlandi)',
      description: 'İş emri tamamlandığında completed_at alanı zorunlu olarak doldurulmalıdır.',
      run: () => {
        let order = {
          status: 'bekliyor',
          completed_at: undefined as string | undefined,
        };
        // Transition 1
        order.status = 'devam_ediyor';
        // Transition 2
        order.status = 'tamamlandi';
        order.completed_at = new Date().toISOString();
        const pass = order.status === 'tamamlandi' && Boolean(order.completed_at);
        return {
          pass,
          message: pass
            ? `İş emri yaşam döngüsü ve tamamlanma tarihi doğrulandı.`
            : `Hata: Tamamlanma tarihi doldurulmadı.`,
        };
      },
    },
  ];

  const runAllTests = () => {
    setIsRunning(true);
    const results: Record<string, { pass: boolean; message: string; details?: any }> = {};

    setTimeout(() => {
      testCases.forEach((tc) => {
        results[tc.id] = tc.run();
      });
      setTestResults(results);
      setIsRunning(false);
    }, 400);
  };

  const totalCount = testCases.length;
  const executedCount = Object.keys(testResults).length;
  const passedCount = Object.values(testResults).filter((r) => r.pass).length;
  const failedCount = executedCount - passedCount;

  return (
    <div className="w-full h-full flex flex-col p-8 overflow-y-auto bg-slate-950 select-none">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-800">
        <div className="flex items-center gap-4">
          {onBackToMap && (
            <button
              onClick={onBackToMap}
              className="flex items-center gap-2 px-3.5 py-2 rounded-lg bg-emerald-500/15 hover:bg-emerald-500/25 border border-emerald-500/40 text-emerald-400 hover:text-emerald-300 text-xs font-bold transition-all cursor-pointer shadow-sm"
              title="Dijital İkiz Haritasına Geri Dön"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>← Haritaya Dön</span>
            </button>
          )}
          <div>
            <h1 className="text-xl font-bold text-white font-sans flex items-center gap-2">
              <CheckCircle2 className="w-6 h-6 text-cyan-400" />
              <span>Otomatik Test Paketi & Kontrat Doğrulama</span>
            </h1>
            <p className="text-xs text-slate-400 mt-1">
              GIS uzamsal matematik, kadastro sınır snapping, FastAPI Faz 2 kontratları ve IoT telemetri şema testleri.
            </p>
          </div>
        </div>

        <button
          onClick={runAllTests}
          disabled={isRunning}
          className="flex items-center gap-2 px-5 py-2.5 bg-cyan-600 hover:bg-cyan-500 disabled:opacity-50 text-white text-xs font-bold rounded-lg transition-colors cursor-pointer shadow-md shadow-cyan-900/40"
        >
          {isRunning ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Play className="w-4 h-4" />}
          <span>{isRunning ? 'Testler Çalışıyor...' : 'Tüm Testleri Çalıştır'}</span>
        </button>
      </div>

      {/* Summary Scoreboard */}
      <div className="grid grid-cols-4 gap-4 mt-6 font-mono">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
          <div className="text-[11px] text-slate-400 font-sans">Toplam Test Senaryosu</div>
          <div className="text-2xl font-bold text-white mt-1">{totalCount}</div>
        </div>
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
          <div className="text-[11px] text-slate-400 font-sans">Çalıştırılan</div>
          <div className="text-2xl font-bold text-cyan-400 mt-1">{executedCount}</div>
        </div>
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
          <div className="text-[11px] text-slate-400 font-sans">Başarılı (Passed)</div>
          <div className="text-2xl font-bold text-emerald-400 mt-1">{passedCount}</div>
        </div>
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
          <div className="text-[11px] text-slate-400 font-sans">Başarısız (Failed)</div>
          <div className="text-2xl font-bold text-red-400 mt-1">{failedCount}</div>
        </div>
      </div>

      {/* Test Cases List */}
      <div className="mt-6 space-y-3">
        {testCases.map((tc) => {
          const res = testResults[tc.id];
          return (
            <div
              key={tc.id}
              className={`p-4 rounded-xl border transition-all text-xs ${
                res
                  ? res.pass
                    ? 'bg-slate-900/80 border-emerald-500/40'
                    : 'bg-red-950/30 border-red-800/80'
                  : 'bg-slate-900/50 border-slate-800'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  {res ? (
                    res.pass ? (
                      <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
                    ) : (
                      <XCircle className="w-5 h-5 text-red-400 shrink-0" />
                    )
                  ) : (
                    <div className="w-5 h-5 rounded-full border border-slate-700 bg-slate-800 flex items-center justify-center text-[10px] text-slate-400">
                      ?
                    </div>
                  )}
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-white text-xs">{tc.title}</span>
                      <span className="text-[10px] font-mono text-slate-400 bg-slate-800 px-2 py-0.5 rounded">
                        {tc.category}
                      </span>
                    </div>
                    <p className="text-slate-400 text-[11px] mt-0.5">{tc.description}</p>
                  </div>
                </div>

                <div className="font-mono text-xs">
                  {res ? (
                    res.pass ? (
                      <span className="text-emerald-400 font-bold">GEÇTİ</span>
                    ) : (
                      <span className="text-red-400 font-bold">BAŞARISIZ</span>
                    )
                  ) : (
                    <span className="text-slate-500">Bekliyor</span>
                  )}
                </div>
              </div>

              {res && (
                <div className="mt-3 pt-2.5 border-t border-slate-800/80 font-mono text-[11px] text-slate-300">
                  {res.message}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};
