import React, { useState } from 'react';
import { Radio, AlertOctagon, CheckCircle2, RefreshCw, Send, BatteryCharging, Droplets, Thermometer, Zap, ArrowLeft } from 'lucide-react';
import { CanonicalAsset, IoTTelemetry } from '../types';

interface IoTTelemetryPanelProps {
  assets: CanonicalAsset[];
  onTriggerDemoTelemetry: () => void;
  telemetryLogs: IoTTelemetry[];
  activeAlerts: { id: string; asset_id: string; title: string; severity: 'warning' | 'critical'; created_at: string }[];
  onAcknowledgeAlert: (alertId: string) => void;
  onCloseAlert: (alertId: string) => void;
  onBackToMap?: () => void;
}

export const IoTTelemetryPanel: React.FC<IoTTelemetryPanelProps> = ({
  assets,
  onTriggerDemoTelemetry,
  telemetryLogs,
  activeAlerts,
  onAcknowledgeAlert,
  onCloseAlert,
  onBackToMap,
}) => {
  const iotAssets = assets.filter((a) => a.properties.iot_connected || a.style.icon === 'sensor' || a.style.icon === 'kuyu');

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
              <Radio className="w-6 h-6 text-orange-400" />
              <span>IoT Canlı Telemetri & Alarm İzleme</span>
            </h1>
            <p className="text-xs text-slate-400 mt-1">
              Saha sensörleri, su kuyusu pompaları ve meteorolojik istasyonlardan gelen anlık veriler (Kontrat: ws.live.telemetry.v1).
            </p>
          </div>
        </div>

        <button
          onClick={onTriggerDemoTelemetry}
          className="flex items-center gap-2 px-4 py-2 bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold rounded-lg transition-colors cursor-pointer shadow-md shadow-orange-900/40"
        >
          <Send className="w-4 h-4" />
          <span>Demo Telemetri Gönder (Tetikle)</span>
        </button>
      </div>

      {/* Grid: Active Alerts & Sensor Nodes */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-6">
        {/* Active Alerts Panel */}
        <div className="lg:col-span-1 bg-slate-900/80 border border-slate-800 rounded-xl p-5 shadow-lg flex flex-col">
          <div className="flex items-center justify-between pb-3 border-b border-slate-800">
            <h2 className="text-sm font-bold text-white flex items-center gap-2">
              <AlertOctagon className="w-4 h-4 text-red-400" />
              <span>Aktif Alarmlar ({activeAlerts.length})</span>
            </h2>
          </div>

          <div className="mt-4 space-y-3 flex-1 overflow-y-auto max-h-[400px]">
            {activeAlerts.length === 0 ? (
              <div className="py-8 text-center text-xs text-slate-500">
                Şu anda aktif veya eşik aşımı uyarısı bulunmuyor. Sistem nominal.
              </div>
            ) : (
              activeAlerts.map((alert) => (
                <div
                  key={alert.id}
                  className={`p-3.5 rounded-lg border text-xs flex flex-col gap-2 ${
                    alert.severity === 'critical'
                      ? 'bg-red-950/40 border-red-800/80 text-red-200'
                      : 'bg-amber-950/40 border-amber-800/80 text-amber-200'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-white font-mono text-[11px]">{alert.id}</span>
                    <span className="text-[10px] uppercase font-mono tracking-wider font-bold">
                      {alert.severity}
                    </span>
                  </div>
                  <p className="font-medium text-slate-100">{alert.title}</p>
                  <div className="flex items-center justify-between pt-2 border-t border-slate-800/60 text-[11px]">
                    <span className="text-slate-400 font-mono">
                      {new Date(alert.created_at).toLocaleTimeString('tr-TR')}
                    </span>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => onAcknowledgeAlert(alert.id)}
                        className="px-2 py-0.5 bg-slate-800 hover:bg-slate-700 rounded text-slate-200 text-[10px] cursor-pointer"
                      >
                        Onayla
                      </button>
                      <button
                        onClick={() => onCloseAlert(alert.id)}
                        className="px-2 py-0.5 bg-slate-800 hover:bg-emerald-900 rounded text-emerald-300 text-[10px] cursor-pointer"
                      >
                        Kapat
                      </button>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Live Connected Nodes */}
        <div className="lg:col-span-2 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-white">Bağlı Saha Düğümleri & Sensörler ({iotAssets.length})</h2>
            <span className="text-xs text-slate-400 font-mono">Protokol: LoRaWAN / MQTT / WS</span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {iotAssets.map((asset) => {
              const card = asset.properties.digital_card?.iot || {};
              return (
                <div key={asset.asset_id} className="bg-slate-900 border border-slate-800 rounded-xl p-4 shadow-md flex flex-col gap-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span
                        className="w-2.5 h-2.5 rounded-full"
                        style={{ backgroundColor: asset.style.color }}
                      />
                      <span className="font-bold text-white text-xs">{asset.name}</span>
                    </div>
                    <span className="text-[10px] font-mono text-emerald-400 font-semibold bg-emerald-950/60 border border-emerald-800/40 px-2 py-0.5 rounded">
                      Canlı Çevrimiçi
                    </span>
                  </div>

                  {/* Telemetry Metrics Grid */}
                  <div className="grid grid-cols-3 gap-2 text-center text-xs font-mono pt-2 border-t border-slate-800">
                    <div className="bg-slate-950/60 p-2 rounded-lg border border-slate-800/80">
                      <div className="text-[10px] text-slate-400 font-sans flex items-center justify-center gap-1">
                        <Droplets className="w-3 h-3 text-sky-400" />
                        <span>Toprak Nemi</span>
                      </div>
                      <div className="text-sm font-bold text-sky-400 mt-1">
                        {card.soil_moisture_pct ?? 26.5}%
                      </div>
                    </div>

                    <div className="bg-slate-950/60 p-2 rounded-lg border border-slate-800/80">
                      <div className="text-[10px] text-slate-400 font-sans flex items-center justify-center gap-1">
                        <Thermometer className="w-3 h-3 text-amber-400" />
                        <span>Sıcaklık</span>
                      </div>
                      <div className="text-sm font-bold text-amber-400 mt-1">
                        {card.air_temperature_c ?? 22.8}°C
                      </div>
                    </div>

                    <div className="bg-slate-950/60 p-2 rounded-lg border border-slate-800/80">
                      <div className="text-[10px] text-slate-400 font-sans flex items-center justify-center gap-1">
                        <Zap className="w-3 h-3 text-emerald-400" />
                        <span>Batarya</span>
                      </div>
                      <div className="text-sm font-bold text-emerald-400 mt-1">
                        {card.battery_pct ?? 95}%
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between text-[10px] text-slate-500 font-mono">
                    <span>Cihaz: {asset.properties.digital_card?.genel?.asset_code || asset.asset_id}</span>
                    <span>Sinyal: {card.signal_dbm ?? -65} dBm</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Live Telemetry Stream Log Table */}
      <div className="mt-8 bg-slate-900 border border-slate-800 rounded-xl overflow-hidden shadow-xl flex flex-col">
        <div className="px-5 py-3 border-b border-slate-800 bg-slate-950/60 flex items-center justify-between">
          <span className="text-xs font-bold text-slate-200">Gelen Telemetri Olay Akışı (Event Log)</span>
          <span className="text-[11px] text-slate-400 font-mono">Kontrat Şeması: ws.live.telemetry.v1</span>
        </div>

        <div className="overflow-x-auto max-h-60">
          <table className="w-full text-left border-collapse text-xs font-mono">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 text-[11px]">
                <th className="py-2.5 px-4">Zaman Damgası</th>
                <th className="py-2.5 px-4">Cihaz ID</th>
                <th className="py-2.5 px-4">Varlık ID</th>
                <th className="py-2.5 px-4">Toprak Nemi</th>
                <th className="py-2.5 px-4">Sıcaklık</th>
                <th className="py-2.5 px-4">Alarmlar</th>
                <th className="py-2.5 px-4">Kalite Bayrağı</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/50">
              {telemetryLogs.map((log, idx) => (
                <tr key={idx} className="hover:bg-slate-800/30">
                  <td className="py-2 px-4 text-slate-400">{log.measured_at}</td>
                  <td className="py-2 px-4 text-slate-200 font-bold">{log.device_id}</td>
                  <td className="py-2 px-4 text-slate-300">{log.asset_id}</td>
                  <td className="py-2 px-4 text-sky-400">{log.metrics.soil_moisture_pct}%</td>
                  <td className="py-2 px-4 text-amber-400">{log.metrics.air_temperature_c}°C</td>
                  <td className="py-2 px-4">
                    {log.alerts.length > 0 ? (
                      <span className="text-red-400 font-bold">{log.alerts.join(', ')}</span>
                    ) : (
                      <span className="text-slate-500">Normal</span>
                    )}
                  </td>
                  <td className="py-2 px-4 text-emerald-400">{log.quality_flag || 'good_quality'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
