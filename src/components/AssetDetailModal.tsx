import React, { useState } from 'react';
import { X, Save, Trash2, ClipboardPlus, Trees, Activity, Radio, Wrench, ShieldAlert } from 'lucide-react';
import { CanonicalAsset, DigitalCard } from '../types';

interface AssetDetailModalProps {
  asset: CanonicalAsset;
  onClose: () => void;
  onSave: (updatedAsset: CanonicalAsset) => void;
  onDelete: (assetId: string) => void;
  onCreateWorkOrder: (asset: CanonicalAsset) => void;
}

type TabKey = 'genel' | 'agac' | 'saglik' | 'iot' | 'bakim' | 'alarm';

export const AssetDetailModal: React.FC<AssetDetailModalProps> = ({
  asset,
  onClose,
  onSave,
  onDelete,
  onCreateWorkOrder,
}) => {
  const [activeTab, setActiveTab] = useState<TabKey>('genel');
  const [name, setName] = useState(asset.name);
  const [digitalCard, setDigitalCard] = useState<DigitalCard>(asset.properties.digital_card || {});

  const updateCardSection = <K extends keyof DigitalCard>(section: K, updates: Partial<NonNullable<DigitalCard[K]>>) => {
    setDigitalCard((prev) => ({
      ...prev,
      [section]: {
        ...(prev[section] || {}),
        ...updates,
      },
    }));
  };

  const handleSave = () => {
    const updated: CanonicalAsset = {
      ...asset,
      name,
      properties: {
        ...asset.properties,
        digital_card: digitalCard,
        timestamps: {
          ...asset.properties.timestamps,
          updated_at: new Date().toISOString(),
          last_operation: 'digital_card_updated',
        },
        audit_log: [
          ...(asset.properties.audit_log || []),
          {
            at: new Date().toISOString(),
            event: 'digital_card_updated_by_operator',
            user: 'operator',
          },
        ],
      },
    };
    onSave(updated);
    onClose();
  };

  const tabs: { key: TabKey; label: string; icon: React.ReactNode }[] = [
    { key: 'genel', label: 'Genel', icon: <Trees className="w-4 h-4" /> },
    { key: 'agac', label: 'Ağaç Künyesi', icon: <Trees className="w-4 h-4 text-emerald-400" /> },
    { key: 'saglik', label: 'Sağlık & Teşhis', icon: <Activity className="w-4 h-4 text-red-400" /> },
    { key: 'iot', label: 'IoT Telemetri', icon: <Radio className="w-4 h-4 text-orange-400" /> },
    { key: 'bakim', label: 'Bakım & Verim', icon: <Wrench className="w-4 h-4 text-sky-400" /> },
    { key: 'alarm', label: 'Alarm Eşikleri', icon: <ShieldAlert className="w-4 h-4 text-amber-400" /> },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm select-none">
      <div className="w-full max-w-3xl bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/50">
          <div className="flex items-center gap-3">
            <span
              className="w-3.5 h-3.5 rounded-full"
              style={{ backgroundColor: asset.style.color }}
            />
            <div>
              <h2 className="text-base font-bold text-white font-sans">{asset.name}</h2>
              <div className="text-xs text-slate-400 font-mono">
                {digitalCard.genel?.asset_code || asset.asset_id} · Yerel: (X: {asset.properties.local_x_m ?? 0}m, Y: {asset.properties.local_y_m ?? 0}m)
              </div>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Tab Navigation */}
        <div className="flex border-b border-slate-800 bg-slate-950/20 px-6 gap-2 overflow-x-auto">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex items-center gap-2 px-3 py-3 text-xs font-semibold border-b-2 transition-colors cursor-pointer whitespace-nowrap ${
                activeTab === tab.key
                  ? 'border-emerald-400 text-emerald-400 bg-slate-800/40'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              {tab.icon}
              <span>{tab.label}</span>
            </button>
          ))}
        </div>

        {/* Tab Content Body */}
        <div className="p-6 overflow-y-auto space-y-4 flex-1 text-xs">
          {activeTab === 'genel' && (
            <div className="space-y-4">
              <div>
                <label className="block text-slate-300 font-medium mb-1">Varlık Adı</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100 focus:outline-none focus:ring-1 focus:ring-emerald-500"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Varlık Kodu</label>
                  <input
                    type="text"
                    value={digitalCard.genel?.asset_code || ''}
                    onChange={(e) => updateCardSection('genel', { asset_code: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100 font-mono"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Fotoğraf URL</label>
                  <input
                    type="text"
                    placeholder="https://..."
                    value={digitalCard.genel?.photo_urls || ''}
                    onChange={(e) => updateCardSection('genel', { photo_urls: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Saha Notları</label>
                <textarea
                  rows={3}
                  value={digitalCard.genel?.notes || ''}
                  onChange={(e) => updateCardSection('genel', { notes: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100 focus:outline-none focus:ring-1 focus:ring-emerald-500"
                />
              </div>
            </div>
          )}

          {activeTab === 'agac' && (
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-slate-300 font-medium mb-1">Ağaç Türü / Botanik İsim</label>
                <input
                  type="text"
                  value={digitalCard.agac?.species || ''}
                  onChange={(e) => updateCardSection('agac', { species: e.target.value })}
                  placeholder="Ceviz, Zeytin, Elma..."
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Çeşit / Varyete</label>
                <input
                  type="text"
                  value={digitalCard.agac?.variety || ''}
                  onChange={(e) => updateCardSection('agac', { variety: e.target.value })}
                  placeholder="Chandler, Gemlik, Pink Lady..."
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Ağaç Yaşı</label>
                <input
                  type="number"
                  value={digitalCard.agac?.age_years || ''}
                  onChange={(e) => updateCardSection('agac', { age_years: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Dikim Tarihi</label>
                <input
                  type="date"
                  value={digitalCard.agac?.planting_date || ''}
                  onChange={(e) => updateCardSection('agac', { planting_date: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Sıra No</label>
                <input
                  type="text"
                  value={digitalCard.agac?.row_no || ''}
                  onChange={(e) => updateCardSection('agac', { row_no: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Ağaç No</label>
                <input
                  type="text"
                  value={digitalCard.agac?.tree_no || ''}
                  onChange={(e) => updateCardSection('agac', { tree_no: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
            </div>
          )}

          {activeTab === 'saglik' && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Teşhis Edilen Hastalık</label>
                  <input
                    type="text"
                    value={digitalCard.saglik?.disease_name || ''}
                    onChange={(e) => updateCardSection('saglik', { disease_name: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Zararlı / Parazit</label>
                  <input
                    type="text"
                    value={digitalCard.saglik?.pest_name || ''}
                    onChange={(e) => updateCardSection('saglik', { pest_name: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Gözlemlenen Belirtiler</label>
                <textarea
                  rows={2}
                  value={digitalCard.saglik?.symptoms || ''}
                  onChange={(e) => updateCardSection('saglik', { symptoms: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Uygulanacak Tedavi & İlaçlama Planı</label>
                <textarea
                  rows={2}
                  value={digitalCard.saglik?.treatment_plan || ''}
                  onChange={(e) => updateCardSection('saglik', { treatment_plan: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
            </div>
          )}

          {activeTab === 'iot' && (
            <div className="grid grid-cols-3 gap-4 font-mono">
              <div>
                <label className="block text-slate-300 font-sans mb-1">Toprak Nemi (%)</label>
                <input
                  type="number"
                  step="0.1"
                  value={digitalCard.iot?.soil_moisture_pct ?? ''}
                  onChange={(e) => updateCardSection('iot', { soil_moisture_pct: parseFloat(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-emerald-400 font-bold"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-sans mb-1">Hava Sıcaklığı (°C)</label>
                <input
                  type="number"
                  step="0.1"
                  value={digitalCard.iot?.air_temperature_c ?? ''}
                  onChange={(e) => updateCardSection('iot', { air_temperature_c: parseFloat(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-amber-400 font-bold"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-sans mb-1">Hava Nemi (%)</label>
                <input
                  type="number"
                  step="0.1"
                  value={digitalCard.iot?.air_humidity_pct ?? ''}
                  onChange={(e) => updateCardSection('iot', { air_humidity_pct: parseFloat(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sky-400 font-bold"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-sans mb-1">Toprak pH</label>
                <input
                  type="number"
                  step="0.01"
                  value={digitalCard.iot?.soil_ph ?? ''}
                  onChange={(e) => updateCardSection('iot', { soil_ph: parseFloat(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-sans mb-1">Toprak EC (mS/cm)</label>
                <input
                  type="number"
                  step="0.01"
                  value={digitalCard.iot?.soil_ec ?? ''}
                  onChange={(e) => updateCardSection('iot', { soil_ec: parseFloat(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-sans mb-1">Batarya Seviyesi (%)</label>
                <input
                  type="number"
                  value={digitalCard.iot?.battery_pct ?? ''}
                  onChange={(e) => updateCardSection('iot', { battery_pct: parseInt(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-emerald-400"
                />
              </div>
            </div>
          )}

          {activeTab === 'bakim' && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Son Sulama Tarihi</label>
                  <input
                    type="datetime-local"
                    value={digitalCard.bakim?.last_irrigation_at?.substring(0, 16) || ''}
                    onChange={(e) => updateCardSection('bakim', { last_irrigation_at: new Date(e.target.value).toISOString() })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Son Gübreleme Tarihi</label>
                  <input
                    type="datetime-local"
                    value={digitalCard.bakim?.last_fertilization_at?.substring(0, 16) || ''}
                    onChange={(e) => updateCardSection('bakim', { last_fertilization_at: new Date(e.target.value).toISOString() })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Son Budama</label>
                  <input
                    type="date"
                    value={digitalCard.bakim?.last_pruning_at || ''}
                    onChange={(e) => updateCardSection('bakim', { last_pruning_at: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Son İlaçlama</label>
                  <input
                    type="date"
                    value={digitalCard.bakim?.last_spray_at || ''}
                    onChange={(e) => updateCardSection('bakim', { last_spray_at: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
              </div>
              <div className="grid grid-cols-3 gap-4 border-t border-slate-800 pt-3">
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Geçen Yıl Verim (kg)</label>
                  <input
                    type="text"
                    value={digitalCard.uretim?.last_yield_kg || ''}
                    onChange={(e) => updateCardSection('uretim', { last_yield_kg: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Beklenen Verim (kg)</label>
                  <input
                    type="text"
                    value={digitalCard.uretim?.expected_yield_kg || ''}
                    onChange={(e) => updateCardSection('uretim', { expected_yield_kg: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Tahmini Meyve Adedi</label>
                  <input
                    type="text"
                    value={digitalCard.uretim?.fruit_count_est || ''}
                    onChange={(e) => updateCardSection('uretim', { fruit_count_est: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
              </div>
            </div>
          )}

          {activeTab === 'alarm' && (
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-slate-300 font-medium mb-1">Minimum Toprak Nemi (%)</label>
                <input
                  type="number"
                  value={digitalCard.alarm?.soil_moisture_min ?? ''}
                  onChange={(e) => updateCardSection('alarm', { soil_moisture_min: parseFloat(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-red-400 font-bold"
                />
                <p className="text-[11px] text-slate-500 mt-1">Bu değerin altına düştüğünde sulama uyarısı oluşturulur.</p>
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Maksimum Toprak Nemi (%)</label>
                <input
                  type="number"
                  value={digitalCard.alarm?.soil_moisture_max ?? ''}
                  onChange={(e) => updateCardSection('alarm', { soil_moisture_max: parseFloat(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-amber-400 font-bold"
                />
                <p className="text-[11px] text-slate-500 mt-1">Fazla sulama ve kök çürümesi riski eşiği.</p>
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Minimum Sıcaklık (°C)</label>
                <input
                  type="number"
                  value={digitalCard.alarm?.air_temperature_min ?? ''}
                  onChange={(e) => updateCardSection('alarm', { air_temperature_min: parseFloat(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sky-400 font-bold"
                />
                <p className="text-[11px] text-slate-500 mt-1">Don riski alarm eşiği.</p>
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Maksimum Sıcaklık (°C)</label>
                <input
                  type="number"
                  value={digitalCard.alarm?.air_temperature_max ?? ''}
                  onChange={(e) => updateCardSection('alarm', { air_temperature_max: parseFloat(e.target.value) })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-red-400 font-bold"
                />
                <p className="text-[11px] text-slate-500 mt-1">Aşırı sıcaklık ve kuraklık stresi alarm eşiği.</p>
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-slate-800 bg-slate-950/50">
          <button
            onClick={() => {
              if (window.confirm(`${asset.name} varlığını silmek istediğinize emin misiniz?`)) {
                onDelete(asset.asset_id);
                onClose();
              }
            }}
            className="flex items-center gap-1.5 px-3 py-2 text-xs font-semibold text-red-400 hover:text-red-300 hover:bg-red-950/40 rounded-lg transition-colors cursor-pointer"
          >
            <Trash2 className="w-4 h-4" />
            <span>Varlığı Sil</span>
          </button>

          <div className="flex items-center gap-3">
            <button
              onClick={() => {
                onCreateWorkOrder(asset);
                onClose();
              }}
              className="flex items-center gap-1.5 px-3.5 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold rounded-lg border border-slate-700 transition-colors cursor-pointer"
            >
              <ClipboardPlus className="w-4 h-4 text-emerald-400" />
              <span>İş Emri Talebi Aç</span>
            </button>
            <button
              onClick={handleSave}
              className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold rounded-lg shadow-md shadow-emerald-900/40 transition-colors cursor-pointer"
            >
              <Save className="w-4 h-4" />
              <span>Değişiklikleri Kaydet</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
