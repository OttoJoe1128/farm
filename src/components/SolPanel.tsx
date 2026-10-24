import React, { useState } from 'react';
import {
  X,
  Radio,
  Droplets,
  Zap,
  Trees,
  Home,
  ShieldCheck,
  ArrowRight,
  Activity,
  Sun,
  Gauge,
  Thermometer,
  Layers,
} from 'lucide-react';
import { CanonicalAsset } from '../types';

interface SolPanelProps {
  onClose: () => void;
  assets: CanonicalAsset[];
  onSelectAsset: (asset: CanonicalAsset) => void;
  onAddWorkOrderFromAsset: (asset: CanonicalAsset) => void;
}

type CategoryTab = 'tum_telemetri' | 'enerji' | 'su' | 'sensorler' | 'agaclar' | 'altyapi';

export const SolPanel: React.FC<SolPanelProps> = ({
  onClose,
  assets,
  onSelectAsset,
  onAddWorkOrderFromAsset,
}) => {
  const [activeTab, setActiveTab] = useState<CategoryTab>('tum_telemetri');

  const solarAssets = assets.filter((a) => a.style.icon === 'gunes' || a.properties.digital_card?.solar);
  const waterAssets = assets.filter(
    (a) => a.style.icon === 'kuyu' || a.style.icon === 'su_borusu' || a.properties.digital_card?.well_pump
  );
  const sensorAssets = assets.filter((a) => a.style.icon === 'sensor');
  const treeAssets = assets.filter((a) => a.style.icon === 'agac');
  const infraAssets = assets.filter(
    (a) =>
      a.style.icon === 'yapi' ||
      a.style.icon === 'trafo' ||
      a.style.icon === 'elektrik_kablo' ||
      a.style.icon === 'su_borusu'
  );

  return (
    <div className="w-full h-full flex flex-col bg-slate-900/95 backdrop-blur-md select-none overflow-hidden text-slate-100">
      {/* Header - Renamed to CANLI SAHA as requested */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-slate-800 bg-slate-950/80">
        <div>
          <h2 className="text-xs font-extrabold tracking-wider text-emerald-400 font-sans uppercase flex items-center gap-1.5">
            <Activity className="w-3.5 h-3.5 text-emerald-400" />
            <span>CANLI SAHA</span>
          </h2>
          <p className="text-[10px] text-slate-400 font-sans">
            Canlı telemetri, varlıklar ve saha altyapısı
          </p>
        </div>
        <button
          onClick={onClose}
          className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
          title="Canlı Saha Panelini Gizle"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Category Pills */}
      <div className="flex items-center gap-1.5 p-2.5 border-b border-slate-800/80 bg-slate-950/40 overflow-x-auto">
        <button
          onClick={() => setActiveTab('tum_telemetri')}
          className={`flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold transition-all cursor-pointer whitespace-nowrap border ${
            activeTab === 'tum_telemetri'
              ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/60'
              : 'bg-slate-800/60 text-slate-400 border-slate-700/60 hover:text-white'
          }`}
        >
          <Activity className="w-3 h-3" />
          <span>Tümü</span>
        </button>
        <button
          onClick={() => setActiveTab('enerji')}
          className={`flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold transition-all cursor-pointer whitespace-nowrap border ${
            activeTab === 'enerji'
              ? 'bg-yellow-500/20 text-yellow-300 border-yellow-500/60'
              : 'bg-slate-800/60 text-slate-400 border-slate-700/60 hover:text-white'
          }`}
        >
          <Sun className="w-3 h-3" />
          <span>Enerji & GES ({solarAssets.length})</span>
        </button>
        <button
          onClick={() => setActiveTab('su')}
          className={`flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold transition-all cursor-pointer whitespace-nowrap border ${
            activeTab === 'su'
              ? 'bg-sky-500/20 text-sky-300 border-sky-500/60'
              : 'bg-slate-800/60 text-slate-400 border-slate-700/60 hover:text-white'
          }`}
        >
          <Droplets className="w-3 h-3" />
          <span>Su & Kuyu ({waterAssets.length})</span>
        </button>
        <button
          onClick={() => setActiveTab('sensorler')}
          className={`flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold transition-all cursor-pointer whitespace-nowrap border ${
            activeTab === 'sensorler'
              ? 'bg-orange-500/20 text-orange-300 border-orange-500/60'
              : 'bg-slate-800/60 text-slate-400 border-slate-700/60 hover:text-white'
          }`}
        >
          <Radio className="w-3 h-3" />
          <span>IoT Toprak ({sensorAssets.length})</span>
        </button>
        <button
          onClick={() => setActiveTab('agaclar')}
          className={`flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold transition-all cursor-pointer whitespace-nowrap border ${
            activeTab === 'agaclar'
              ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/60'
              : 'bg-slate-800/60 text-slate-400 border-slate-700/60 hover:text-white'
          }`}
        >
          <Trees className="w-3 h-3" />
          <span>Ağaçlar ({treeAssets.length})</span>
        </button>
        <button
          onClick={() => setActiveTab('altyapi')}
          className={`flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold transition-all cursor-pointer whitespace-nowrap border ${
            activeTab === 'altyapi'
              ? 'bg-purple-500/20 text-purple-300 border-purple-500/60'
              : 'bg-slate-800/60 text-slate-400 border-slate-700/60 hover:text-white'
          }`}
        >
          <Layers className="w-3 h-3" />
          <span>Hat & Altyapı ({infraAssets.length})</span>
        </button>
      </div>

      {/* Body List */}
      <div className="flex-1 overflow-y-auto p-3 space-y-2.5">
        {/* Render Solar Power Plant (GES) Cards */}
        {(activeTab === 'tum_telemetri' || activeTab === 'enerji') &&
          solarAssets.map((asset) => {
            const solar = asset.properties.digital_card?.solar;
            return (
              <div
                key={asset.asset_id}
                onClick={() => onSelectAsset(asset)}
                className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 hover:border-yellow-500/50 transition-all cursor-pointer flex flex-col gap-2 shadow-sm"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="p-1.5 rounded-lg bg-yellow-500/10 text-yellow-400">
                      <Sun className="w-3.5 h-3.5" />
                    </div>
                    <div>
                      <div className="font-bold text-xs text-white">{asset.name}</div>
                      <div className="text-[10px] text-slate-400 font-mono">
                        {asset.properties.digital_card?.genel?.asset_code || asset.asset_id}
                      </div>
                    </div>
                  </div>
                  <span className="text-[9px] font-mono px-2 py-0.5 rounded font-bold bg-yellow-950 text-yellow-300 border border-yellow-800/60">
                    ÜRETİMDE
                  </span>
                </div>

                {/* Specialized Solar Metrics: Power kW, Daily kWh, Inverter Efficiency %, Irradiance */}
                <div className="grid grid-cols-3 gap-1.5 font-mono text-center pt-1.5 border-t border-slate-800/80">
                  <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                    <div className="text-[9px] text-slate-400 font-sans">Anlık Güç</div>
                    <div className="text-xs font-bold text-yellow-400">
                      {solar?.current_power_kw ?? 24.6} kW
                    </div>
                  </div>
                  <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                    <div className="text-[9px] text-slate-400 font-sans">Günlük Üretim</div>
                    <div className="text-xs font-bold text-emerald-400">
                      {solar?.daily_yield_kwh ?? 142.8} kWh
                    </div>
                  </div>
                  <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                    <div className="text-[9px] text-slate-400 font-sans">İnvertör Verimi</div>
                    <div className="text-xs font-bold text-sky-400">
                      %{solar?.inverter_efficiency_pct ?? 98.4}
                    </div>
                  </div>
                </div>

                <div className="flex items-center justify-between text-[10px] text-slate-400 font-mono">
                  <span>
                    Işınım: {solar?.irradiance_w_m2 ?? 845} W/m² · Sıcaklık: {solar?.panel_temperature_c ?? 34.2}°C
                  </span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onAddWorkOrderFromAsset(asset);
                    }}
                    className="text-emerald-400 hover:text-emerald-300 font-sans font-semibold text-[10px] flex items-center gap-0.5 cursor-pointer"
                  >
                    <span>İş Emri Aç</span>
                    <ArrowRight className="w-3 h-3" />
                  </button>
                </div>
              </div>
            );
          })}

        {/* Render Deep Well & Pump Station Cards */}
        {(activeTab === 'tum_telemetri' || activeTab === 'su') &&
          waterAssets.map((asset) => {
            const pump = asset.properties.digital_card?.well_pump;
            const waterInfra = asset.properties.digital_card?.water_infra;
            const isPipe = asset.style.icon === 'su_borusu';

            return (
              <div
                key={asset.asset_id}
                onClick={() => onSelectAsset(asset)}
                className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 hover:border-sky-500/50 transition-all cursor-pointer flex flex-col gap-2 shadow-sm"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="p-1.5 rounded-lg bg-sky-500/10 text-sky-400">
                      <Droplets className="w-3.5 h-3.5" />
                    </div>
                    <div>
                      <div className="font-bold text-xs text-white">{asset.name}</div>
                      <div className="text-[10px] text-slate-400 font-mono">
                        {asset.properties.digital_card?.genel?.asset_code || asset.asset_id}
                      </div>
                    </div>
                  </div>
                  <span className="text-[9px] font-mono px-2 py-0.5 rounded font-bold bg-sky-950 text-sky-300 border border-sky-800/60">
                    {pump?.motor_status === 'calisiyor' || waterInfra?.valve_status === 'acik' ? 'AKTİF' : 'BEKLEMEDE'}
                  </span>
                </div>

                {/* Specialized Deep Well & Pump Metrics: Depth, Water Level, Flow Rate, Pressure */}
                {!isPipe && (
                  <div className="grid grid-cols-3 gap-1.5 font-mono text-center pt-1.5 border-t border-slate-800/80">
                    <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                      <div className="text-[9px] text-slate-400 font-sans">Kuyu / Seviye</div>
                      <div className="text-xs font-bold text-sky-400">
                        {pump?.well_depth_m ?? 140}m / {pump?.dynamic_water_level_m ?? 64.2}m
                      </div>
                    </div>
                    <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                      <div className="text-[9px] text-slate-400 font-sans">Anlık Debi</div>
                      <div className="text-xs font-bold text-emerald-400">
                        {pump?.flow_rate_m3_h ?? 46.5} m³/saat
                      </div>
                    </div>
                    <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                      <div className="text-[9px] text-slate-400 font-sans">Hat Basıncı</div>
                      <div className="text-xs font-bold text-amber-400">
                        {pump?.line_pressure_bar ?? 4.8} bar
                      </div>
                    </div>
                  </div>
                )}

                {/* Linear Water Pipe Metrics */}
                {isPipe && (
                  <div className="grid grid-cols-3 gap-1.5 font-mono text-center pt-1.5 border-t border-slate-800/80">
                    <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                      <div className="text-[9px] text-slate-400 font-sans">Boru Spesifikasyonu</div>
                      <div className="text-xs font-bold text-sky-400">
                        {waterInfra?.pipe_spec || 'Ø90 HDPE'}
                      </div>
                    </div>
                    <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                      <div className="text-[9px] text-slate-400 font-sans">Basınç</div>
                      <div className="text-xs font-bold text-emerald-400">
                        {waterInfra?.line_pressure_bar ?? 3.8} bar
                      </div>
                    </div>
                    <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                      <div className="text-[9px] text-slate-400 font-sans">Vana Durumu</div>
                      <div className="text-xs font-bold text-cyan-400">
                        {waterInfra?.valve_status === 'acik' ? 'Açık' : 'Kapalı'}
                      </div>
                    </div>
                  </div>
                )}

                <div className="flex items-center justify-between text-[10px] text-slate-400 font-mono">
                  <span>
                    {!isPipe
                      ? `Motor: ${pump?.motor_power_kw ?? 15} kW · Akım: ${pump?.motor_current_a ?? 28.6}A @ 380V`
                      : `Filtre ΔP: ${waterInfra?.filter_dp_bar ?? 0.25} bar · Hat: ~${waterInfra?.line_length_m ?? 54}m`}
                  </span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onAddWorkOrderFromAsset(asset);
                    }}
                    className="text-emerald-400 hover:text-emerald-300 font-sans font-semibold text-[10px] flex items-center gap-0.5 cursor-pointer"
                  >
                    <span>İş Emri Aç</span>
                    <ArrowRight className="w-3 h-3" />
                  </button>
                </div>
              </div>
            );
          })}

        {/* Render IoT Soil & Weather Sensor Cards */}
        {(activeTab === 'tum_telemetri' || activeTab === 'sensorler') &&
          sensorAssets.map((asset) => {
            const card = asset.properties.digital_card?.iot || {};
            const moisture = card.soil_moisture_pct ?? 22.4;
            const isMoistureLow = typeof moisture === 'number' && moisture < 20.0;

            return (
              <div
                key={asset.asset_id}
                onClick={() => onSelectAsset(asset)}
                className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 hover:border-orange-500/50 transition-all cursor-pointer flex flex-col gap-2 shadow-sm"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="p-1.5 rounded-lg bg-orange-500/10 text-orange-400">
                      <Radio className="w-3.5 h-3.5" />
                    </div>
                    <div>
                      <div className="font-bold text-xs text-white">{asset.name}</div>
                      <div className="text-[10px] text-slate-400 font-mono">
                        {asset.properties.digital_card?.genel?.asset_code || asset.asset_id}
                      </div>
                    </div>
                  </div>
                  <span
                    className={`text-[9px] font-mono px-2 py-0.5 rounded font-bold ${
                      isMoistureLow
                        ? 'bg-red-950 text-red-400 border border-red-800/60'
                        : 'bg-emerald-950 text-emerald-400 border border-emerald-800/60'
                    }`}
                  >
                    {isMoistureLow ? 'KRİTİK NEM' : 'ÇEVRİMİÇİ'}
                  </span>
                </div>

                {/* Specialized Soil Moisture Profile (20cm & 50cm), Temp & Battery */}
                <div className="grid grid-cols-3 gap-1.5 font-mono text-center pt-1.5 border-t border-slate-800/80">
                  <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                    <div className="text-[9px] text-slate-400 font-sans">Kök Nemi (20cm)</div>
                    <div className={`text-xs font-bold ${isMoistureLow ? 'text-red-400' : 'text-sky-400'}`}>
                      %{moisture}
                    </div>
                  </div>
                  <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                    <div className="text-[9px] text-slate-400 font-sans">Alt Nem (50cm)</div>
                    <div className="text-xs font-bold text-emerald-400">
                      %{card.soil_moisture_deep_pct ?? 28.6}
                    </div>
                  </div>
                  <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                    <div className="text-[9px] text-slate-400 font-sans">Hava Sıcaklığı</div>
                    <div className="text-xs font-bold text-amber-400">
                      {card.air_temperature_c ?? 24.8}°C
                    </div>
                  </div>
                </div>

                <div className="flex items-center justify-between text-[10px] text-slate-400 font-mono">
                  <span>
                    pH: {card.soil_ph ?? 6.85} · EC: {card.soil_ec ?? 1.25} mS/cm · Pil: %{card.battery_pct ?? 91}
                  </span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onAddWorkOrderFromAsset(asset);
                    }}
                    className="text-emerald-400 hover:text-emerald-300 font-sans font-semibold text-[10px] flex items-center gap-0.5 cursor-pointer"
                  >
                    <span>İş Emri Aç</span>
                    <ArrowRight className="w-3 h-3" />
                  </button>
                </div>
              </div>
            );
          })}

        {/* Render Trees */}
        {(activeTab === 'tum_telemetri' || activeTab === 'agaclar') &&
          treeAssets.map((asset) => {
            const agac = asset.properties.digital_card?.agac || {};
            const uretim = asset.properties.digital_card?.uretim || {};
            return (
              <div
                key={asset.asset_id}
                onClick={() => onSelectAsset(asset)}
                className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 hover:border-emerald-500/50 transition-all cursor-pointer flex flex-col gap-1.5 shadow-sm"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="p-1.5 rounded-lg bg-emerald-500/10 text-emerald-400">
                      <Trees className="w-3.5 h-3.5" />
                    </div>
                    <div>
                      <div className="font-bold text-xs text-white">{asset.name}</div>
                      <div className="text-[10px] text-slate-400">
                        {agac.species || 'Ceviz (Juglans regia)'} · {agac.variety || 'Chandler'}
                      </div>
                    </div>
                  </div>
                  <span className="text-[9px] font-mono text-emerald-400 bg-emerald-950/60 border border-emerald-800/40 px-1.5 py-0.5 rounded font-bold">
                    NDVI {agac.ndvi_score ?? 0.84}
                  </span>
                </div>
                <div className="text-[10px] text-slate-400 flex items-center justify-between font-mono pt-1 border-t border-slate-800/60">
                  <span>Sıra/Ağaç: {agac.row_no || '2'}/{agac.tree_no || '14'}</span>
                  <span>Yaş: {agac.age_years || '4'} yıl</span>
                  <span className="text-emerald-400">Tahmini: {uretim.expected_yield_kg || '48'} kg</span>
                </div>
              </div>
            );
          })}

        {/* Render Infrastructure & Buildings */}
        {(activeTab === 'tum_telemetri' || activeTab === 'altyapi') &&
          infraAssets.map((asset) => {
            const elec = asset.properties.digital_card?.electric_infra;
            const isTrafo = asset.style.icon === 'trafo';
            const isKablo = asset.style.icon === 'elektrik_kablo';

            return (
              <div
                key={asset.asset_id}
                onClick={() => onSelectAsset(asset)}
                className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 hover:border-purple-500/50 transition-all cursor-pointer flex flex-col gap-2 shadow-sm"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="p-1.5 rounded-lg bg-purple-500/10 text-purple-400">
                      {isTrafo || isKablo ? <Zap className="w-3.5 h-3.5 text-yellow-400" /> : <Home className="w-3.5 h-3.5 text-amber-400" />}
                    </div>
                    <div>
                      <div className="font-bold text-xs text-white">{asset.name}</div>
                      <div className="text-[10px] text-slate-400 font-mono">
                        {asset.properties.digital_card?.genel?.asset_code || asset.asset_id}
                      </div>
                    </div>
                  </div>
                  <span className="text-[9px] font-mono text-emerald-400 bg-emerald-950/60 border border-emerald-800/40 px-1.5 py-0.5 rounded font-bold">
                    {elec?.status === 'aktif' ? 'ENERJİLİ' : 'AKTİF'}
                  </span>
                </div>

                {elec && (
                  <div className="grid grid-cols-3 gap-1.5 font-mono text-center pt-1.5 border-t border-slate-800/80">
                    <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                      <div className="text-[9px] text-slate-400 font-sans">Kapasite/Yük</div>
                      <div className="text-xs font-bold text-yellow-400">
                        {isTrafo ? `${elec.transformer_capacity_kva} kVA` : `${elec.active_load_kw} kW`}
                      </div>
                    </div>
                    <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                      <div className="text-[9px] text-slate-400 font-sans">Gerilim</div>
                      <div className="text-xs font-bold text-sky-400">
                        {elec.secondary_voltage_v} V
                      </div>
                    </div>
                    <div className="p-1 rounded bg-slate-900/90 border border-slate-800">
                      <div className="text-[9px] text-slate-400 font-sans">Kablo Tipi</div>
                      <div className="text-[10px] font-bold text-emerald-400 truncate">
                        {elec.cable_spec.split(' ')[0]}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
      </div>
    </div>
  );
};
