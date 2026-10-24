import React from 'react';
import { Trees, Home, Droplets, Radio, Sun, Ruler, Trash2 } from 'lucide-react';
import { AssetType } from '../types';

interface AssetToolbarProps {
  selectedTool: AssetType | null;
  onSelectTool: (tool: AssetType) => void;
  onClearAllAssets: () => void;
  assetCount: number;
}

export const AssetToolbar: React.FC<AssetToolbarProps> = ({
  selectedTool,
  onSelectTool,
  onClearAllAssets,
  assetCount,
}) => {
  const tools: { id: AssetType; label: string; icon: React.ReactNode; color: string; activeBg: string }[] = [
    {
      id: 'agac',
      label: 'Ağaç',
      icon: <Trees className="w-5 h-5" />,
      color: 'text-emerald-400',
      activeBg: 'bg-emerald-950/80 border-emerald-500 shadow-emerald-900/40',
    },
    {
      id: 'yapi',
      label: 'Yapı / Tesis',
      icon: <Home className="w-5 h-5" />,
      color: 'text-amber-500',
      activeBg: 'bg-amber-950/80 border-amber-500 shadow-amber-900/40',
    },
    {
      id: 'kuyu',
      label: 'Su Kuyusu',
      icon: <Droplets className="w-5 h-5" />,
      color: 'text-sky-400',
      activeBg: 'bg-sky-950/80 border-sky-500 shadow-sky-900/40',
    },
    {
      id: 'sensor',
      label: 'IoT Sensör',
      icon: <Radio className="w-5 h-5" />,
      color: 'text-orange-400',
      activeBg: 'bg-orange-950/80 border-orange-500 shadow-orange-900/40',
    },
    {
      id: 'gunes',
      label: 'Güneş Paneli',
      icon: <Sun className="w-5 h-5" />,
      color: 'text-yellow-400',
      activeBg: 'bg-yellow-950/80 border-yellow-500 shadow-yellow-900/40',
    },
    {
      id: 'olcum',
      label: 'Ölçüm Cetveli',
      icon: <Ruler className="w-5 h-5" />,
      color: 'text-cyan-400',
      activeBg: 'bg-cyan-950/80 border-cyan-500 shadow-cyan-900/40',
    },
  ];

  return (
    <div className="absolute bottom-8 left-1/2 -translate-x-1/2 z-20 flex flex-col items-center gap-2 select-none pointer-events-auto">
      {/* Active Mode Info Prompt */}
      {selectedTool && (
        <div className="px-3 py-1 rounded-full bg-slate-900/95 border border-slate-700 text-xs text-slate-200 backdrop-blur-md shadow-lg animate-in fade-in duration-150">
          {selectedTool === 'olcum' ? (
            <span>Mesafe ölçmek için haritaya ardışık noktalar ekleyin.</span>
          ) : (
            <span>
              Parsel içinde tıklayarak <strong>{tools.find((t) => t.id === selectedTool)?.label}</strong> ekleyin (2m snap aktif).
            </span>
          )}
        </div>
      )}

      {/* Floating Dock */}
      <div className="flex items-center gap-2 px-3 py-2 bg-slate-900/90 backdrop-blur-xl border border-slate-700/80 rounded-2xl shadow-2xl">
        {tools.map((tool) => {
          const isActive = selectedTool === tool.id;
          return (
            <button
              key={tool.id}
              onClick={() => onSelectTool(tool.id)}
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold transition-all duration-150 cursor-pointer border ${
                isActive
                  ? `${tool.activeBg} ${tool.color} border shadow-lg scale-105`
                  : 'bg-slate-800/80 text-slate-300 border-slate-700/60 hover:bg-slate-700 hover:text-white'
              }`}
              title={`${tool.label} eklemek için tıklayın`}
            >
              {tool.icon}
              <span className="hidden sm:inline whitespace-nowrap">{tool.label}</span>
            </button>
          );
        })}

        {assetCount > 0 && (
          <>
            <div className="w-px h-6 bg-slate-700 mx-1" />
            <button
              onClick={() => {
                if (window.confirm('Tüm varlıkları temizlemek istediğinizden emin misiniz?')) {
                  onClearAllAssets();
                }
              }}
              className="p-2 rounded-xl text-xs text-slate-400 hover:text-red-400 hover:bg-red-950/40 border border-transparent hover:border-red-800/60 transition-colors cursor-pointer"
              title="Tüm varlıkları temizle"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </>
        )}
      </div>
    </div>
  );
};
