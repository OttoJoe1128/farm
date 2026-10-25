import React, { useState, useRef, useEffect } from 'react';
import {
  Menu,
  X,
  Map,
  ClipboardList,
  Radio,
  ShieldCheck,
  CheckCircle2,
  Upload,
  Satellite,
  Send,
  Wrench,
  RefreshCw,
  Database,
  SlidersHorizontal,
  Bell,
  ArrowLeft,
  ChevronDown,
  Download,
} from 'lucide-react';
import { ParcelFeature, FarmKpi } from '../types';
import { getParcelId, getParcelLabel } from '../services/gisService';

export type ActiveTab = 'map' | 'work_orders' | 'telemetry' | 'admin' | 'tests';

interface TopBarProps {
  activeTab: ActiveTab;
  onTabChange: (tab: ActiveTab) => void;
  selectedParcel: ParcelFeature | null;
  parcels: ParcelFeature[];
  onSelectParcel: (parcel: ParcelFeature) => void;
  satelliteMode: boolean;
  onToggleSatellite: () => void;
  onUploadParcelClick: () => void;
  onExportBackupClick: () => void;
  onFieldIngestClick: () => void;
  onWorkOrderQuickClick: () => void;
  onIoTDemoClick: () => void;
  onErpSyncClick: () => void;
  onOverviewResetClick: () => void;
  isSolPanelOpen: boolean;
  onToggleSolPanel: () => void;
  isSagPanelOpen: boolean;
  onToggleSagPanel: () => void;
  kpi: FarmKpi;
}

export const TopBar: React.FC<TopBarProps> = ({
  activeTab,
  onTabChange,
  selectedParcel,
  parcels,
  onSelectParcel,
  satelliteMode,
  onToggleSatellite,
  onUploadParcelClick,
  onExportBackupClick,
  onFieldIngestClick,
  onWorkOrderQuickClick,
  onIoTDemoClick,
  onErpSyncClick,
  onOverviewResetClick,
  isSolPanelOpen,
  onToggleSolPanel,
  isSagPanelOpen,
  onToggleSagPanel,
  kpi,
}) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const menuTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  const handleMouseEnter = () => {
    if (menuTimeoutRef.current) clearTimeout(menuTimeoutRef.current);
    setIsMenuOpen(true);
  };

  const handleMouseLeave = () => {
    menuTimeoutRef.current = setTimeout(() => {
      setIsMenuOpen(false);
    }, 300);
  };

  return (
    <header className="w-full bg-slate-900 border-b border-slate-800 z-40 select-none shrink-0 shadow-md">
      <div className="flex items-center justify-between px-4 py-2.5 gap-4">
        {/* Left: Hamburger Menu & Brand */}
        <div className="flex items-center gap-3">
          {/* Hoverable / Clickable Hamburger Menu Container */}
          <div
            className="relative"
            onMouseEnter={handleMouseEnter}
            onMouseLeave={handleMouseLeave}
          >
            <button
              onClick={() => setIsMenuOpen(!isMenuOpen)}
              className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-100 border border-slate-700 transition-colors cursor-pointer text-xs font-bold"
              aria-expanded={isMenuOpen}
              aria-label="Menüyü Aç"
            >
              <Menu className="w-4 h-4 text-emerald-400" />
              <span className="hidden sm:inline">Menü</span>
              <ChevronDown className={`w-3.5 h-3.5 transition-transform ${isMenuOpen ? 'rotate-180' : ''}`} />
            </button>

            {/* Dropdown Drawer Menu */}
            {isMenuOpen && (
              <div
                className="absolute top-full left-0 mt-1 w-64 bg-slate-900 border border-slate-700 rounded-xl shadow-2xl p-2 z-50 animate-in fade-in slide-in-from-top-2 duration-150 text-xs"
                onMouseEnter={handleMouseEnter}
                onMouseLeave={handleMouseLeave}
              >
                {/* Sayfalar Grubu */}
                <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider px-2 py-1">
                  Sayfalar
                </div>
                <div className="space-y-0.5">
                  <button
                    onClick={() => {
                      onTabChange('map');
                      setIsMenuOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-left transition-colors cursor-pointer ${
                      activeTab === 'map' ? 'bg-emerald-500/20 text-emerald-300 font-bold' : 'text-slate-200 hover:bg-slate-800'
                    }`}
                  >
                    <Map className="w-4 h-4 text-emerald-400" />
                    <span>Dijital İkiz Haritası</span>
                  </button>
                  <button
                    onClick={() => {
                      onTabChange('work_orders');
                      setIsMenuOpen(false);
                    }}
                    className={`w-full flex items-center justify-between px-2.5 py-2 rounded-lg text-left transition-colors cursor-pointer ${
                      activeTab === 'work_orders' ? 'bg-emerald-500/20 text-emerald-300 font-bold' : 'text-slate-200 hover:bg-slate-800'
                    }`}
                  >
                    <div className="flex items-center gap-2">
                      <ClipboardList className="w-4 h-4 text-blue-400" />
                      <span>İş Emirleri</span>
                    </div>
                    {kpi.work_orders_open > 0 && (
                      <span className="text-[10px] font-mono text-blue-400 font-bold">
                        ({kpi.work_orders_open})
                      </span>
                    )}
                  </button>
                  <button
                    onClick={() => {
                      onTabChange('telemetry');
                      setIsMenuOpen(false);
                    }}
                    className={`w-full flex items-center justify-between px-2.5 py-2 rounded-lg text-left transition-colors cursor-pointer ${
                      activeTab === 'telemetry' ? 'bg-emerald-500/20 text-emerald-300 font-bold' : 'text-slate-200 hover:bg-slate-800'
                    }`}
                  >
                    <div className="flex items-center gap-2">
                      <Radio className="w-4 h-4 text-orange-400" />
                      <span>IoT & Telemetri</span>
                    </div>
                    {kpi.alerts_count > 0 && (
                      <span className="text-[10px] font-mono text-red-400 font-bold">
                        ({kpi.alerts_count})
                      </span>
                    )}
                  </button>
                  <button
                    onClick={() => {
                      onTabChange('admin');
                      setIsMenuOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-left transition-colors cursor-pointer ${
                      activeTab === 'admin' ? 'bg-emerald-500/20 text-emerald-300 font-bold' : 'text-slate-200 hover:bg-slate-800'
                    }`}
                  >
                    <ShieldCheck className="w-4 h-4 text-purple-400" />
                    <span>Admin Paneli</span>
                  </button>
                  <button
                    onClick={() => {
                      onTabChange('tests');
                      setIsMenuOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-left transition-colors cursor-pointer ${
                      activeTab === 'tests' ? 'bg-emerald-500/20 text-emerald-300 font-bold' : 'text-slate-200 hover:bg-slate-800'
                    }`}
                  >
                    <CheckCircle2 className="w-4 h-4 text-cyan-400" />
                    <span>Otomatik Test Paketi</span>
                  </button>
                </div>

                {/* Hızlı Aksiyonlar */}
                <div className="border-t border-slate-800 my-1 pt-1">
                  <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider px-2 py-1">
                    Hızlı İşlemler
                  </div>
                  <div className="space-y-0.5">
                    <button
                      onClick={() => {
                        onOverviewResetClick();
                        setIsMenuOpen(false);
                      }}
                      className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-rose-300 hover:bg-slate-800 text-left transition-colors cursor-pointer"
                    >
                      <ArrowLeft className="w-3.5 h-3.5" />
                      <span>Genel Bakışa Dön</span>
                    </button>
                    <button
                      onClick={() => {
                        onUploadParcelClick();
                        setIsMenuOpen(false);
                      }}
                      className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-slate-200 hover:bg-slate-800 text-left transition-colors cursor-pointer"
                    >
                      <Upload className="w-3.5 h-3.5 text-sky-400" />
                      <span>Parsel / Yedek Yükle (.geojson, .json)</span>
                    </button>
                    <button
                      onClick={() => {
                        onExportBackupClick();
                        setIsMenuOpen(false);
                      }}
                      className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-slate-200 hover:bg-slate-800 text-left transition-colors cursor-pointer"
                    >
                      <Download className="w-3.5 h-3.5 text-amber-400" />
                      <span>Verileri Yedekle (JSON)</span>
                    </button>
                    <button
                      onClick={() => {
                        onToggleSatellite();
                        setIsMenuOpen(false);
                      }}
                      className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-slate-200 hover:bg-slate-800 text-left transition-colors cursor-pointer"
                    >
                      <Satellite className="w-3.5 h-3.5 text-emerald-400" />
                      <span>{satelliteMode ? 'Sokak Haritasına Geç' : 'Uyduyu Getir (ESRI)'}</span>
                    </button>
                    <button
                      onClick={() => {
                        onFieldIngestClick();
                        setIsMenuOpen(false);
                      }}
                      className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-teal-300 hover:bg-slate-800 text-left transition-colors cursor-pointer"
                    >
                      <Database className="w-3.5 h-3.5" />
                      <span>Saha GPS İçe Aktar</span>
                    </button>
                    <button
                      onClick={() => {
                        onWorkOrderQuickClick();
                        setIsMenuOpen(false);
                      }}
                      className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-blue-300 hover:bg-slate-800 text-left transition-colors cursor-pointer"
                    >
                      <Wrench className="w-3.5 h-3.5" />
                      <span>Yeni İş Emri Talebi</span>
                    </button>
                    <button
                      onClick={() => {
                        onIoTDemoClick();
                        setIsMenuOpen(false);
                      }}
                      className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-orange-400 hover:bg-slate-800 text-left transition-colors cursor-pointer"
                    >
                      <Send className="w-3.5 h-3.5" />
                      <span>IoT Demo Telemetri Gönder</span>
                    </button>
                    <button
                      onClick={() => {
                        onErpSyncClick();
                        setIsMenuOpen(false);
                      }}
                      className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-indigo-300 hover:bg-slate-800 text-left transition-colors cursor-pointer"
                    >
                      <RefreshCw className="w-3.5 h-3.5" />
                      <span>ERP Senkronizasyonu</span>
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Wordmark */}
          <span className="font-extrabold text-white text-sm tracking-tight whitespace-nowrap">
            SmartFarm <span className="text-emerald-400">XR</span>
          </span>
        </div>

        {/* Center: Selected Parcel Info & Selector */}
        <div className="flex items-center gap-2 overflow-hidden">
          {/* Parcel Selector Dropdown */}
          <select
            aria-label="Parsel Seçin"
            value={getParcelId(selectedParcel) || ''}
            onChange={(e) => {
              const found = parcels.find((p) => getParcelId(p) === e.target.value);
              if (found) onSelectParcel(found);
            }}
            className="bg-slate-950 border border-slate-700 text-slate-200 text-xs rounded-lg px-2.5 py-1.5 focus:outline-none focus:ring-1 focus:ring-emerald-500 cursor-pointer"
          >
            {parcels.map((p) => (
              <option key={getParcelId(p)} value={getParcelId(p)}>
                {getParcelLabel(p)} ({p.properties.Il || 'TKGM'})
              </option>
            ))}
          </select>

          {/* Parcel Glass Badge */}
          <div className="hidden lg:flex items-center gap-2 px-3 py-1 bg-slate-950/80 border border-slate-800 rounded-lg text-xs font-sans text-slate-300">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            <span className="font-bold text-white">
              {selectedParcel?.properties.Alan || '-'}
            </span>
            <span className="text-slate-600">·</span>
            <span>{selectedParcel?.properties.Nitelik || 'Tarla'}</span>
            <span className="text-slate-600">·</span>
            <span className="text-emerald-400 font-mono text-[11px]">
              {satelliteMode ? 'Uydu: ESRI' : 'Sokak: OSM'}
            </span>
          </div>
        </div>

        {/* Right: Docked Panel Toggles & KPI Badges */}
        <div className="flex items-center gap-2">
          {/* Canlı Saha Paneli Toggle */}
          <button
            onClick={onToggleSolPanel}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs font-bold transition-all cursor-pointer ${
              isSolPanelOpen
                ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/60'
                : 'bg-slate-800 hover:bg-slate-700 text-slate-300 border-slate-700'
            }`}
            title="Canlı Saha Panelini (Telemetri & Varlıklar) Göster/Gizle"
          >
            <SlidersHorizontal className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Canlı Saha</span>
          </button>

          {/* Sağ Panel Toggle */}
          <button
            onClick={onToggleSagPanel}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs font-bold transition-all cursor-pointer ${
              isSagPanelOpen || kpi.alerts_count > 0
                ? 'bg-red-500/20 text-red-400 border-red-500/60'
                : 'bg-slate-800 hover:bg-slate-700 text-slate-300 border-slate-700'
            }`}
            title="Sağ Paneli (Alarmlar) Göster/Gizle"
          >
            <Bell className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Alarmlar</span>
            {kpi.alerts_count > 0 && (
              <span className="text-[10px] bg-red-950 px-1.5 py-0.2 rounded font-mono text-red-400 font-extrabold">
                {kpi.alerts_count}
              </span>
            )}
          </button>

          {/* Quick Satellite Toggle Button */}
          <button
            onClick={onToggleSatellite}
            className="p-1.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-lg text-slate-300 cursor-pointer"
            title={satelliteMode ? 'Vektör Haritaya Geç' : 'Uydu Katmanına Geç'}
          >
            <Satellite className="w-4 h-4 text-emerald-400" />
          </button>
        </div>
      </div>
    </header>
  );
};
