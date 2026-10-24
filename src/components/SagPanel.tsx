import React from 'react';
import { X, AlertOctagon, CheckCircle2, ClipboardPlus, Bell } from 'lucide-react';

interface AlertItem {
  id: string;
  asset_id: string;
  title: string;
  severity: 'warning' | 'critical';
  created_at: string;
  message?: string;
}

interface SagPanelProps {
  onClose: () => void;
  alerts: AlertItem[];
  onAcknowledge: (alertId: string) => void;
  onCloseAlert: (alertId: string) => void;
  onCreateWorkOrderFromAlert: (alert: AlertItem) => void;
}

export const SagPanel: React.FC<SagPanelProps> = ({
  onClose,
  alerts,
  onAcknowledge,
  onCloseAlert,
  onCreateWorkOrderFromAlert,
}) => {
  return (
    <div className="w-full h-full flex flex-col bg-slate-900/95 backdrop-blur-md select-none overflow-hidden text-slate-100">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-slate-800 bg-slate-950/80">
        <div className="flex items-center gap-2">
          <AlertOctagon className="w-4 h-4 text-red-400" />
          <div>
            <h2 className="text-xs font-extrabold tracking-wider text-red-400 font-sans uppercase">
              UYARILAR & ALARMLAR ({alerts.length})
            </h2>
            <p className="text-[10px] text-slate-400 font-sans">
              Gerçek zamanlı saha alarmları
            </p>
          </div>
        </div>
        <button
          onClick={onClose}
          className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
          title="Paneli Gizle"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Alerts List */}
      <div className="flex-1 overflow-y-auto p-3 space-y-2.5">
        {alerts.length === 0 ? (
          <div className="py-16 text-center text-xs text-slate-500 flex flex-col items-center gap-2">
            <CheckCircle2 className="w-7 h-7 text-emerald-500/50" />
            <span>Aktif sistem uyarısı veya kritik alarm bulunmamaktadır.</span>
          </div>
        ) : (
          alerts.map((alert) => (
            <div
              key={alert.id}
              className={`p-3 rounded-xl border text-xs flex flex-col gap-1.5 shadow-md transition-all ${
                alert.severity === 'critical'
                  ? 'bg-red-950/40 border-red-800/80 text-red-100'
                  : 'bg-amber-950/30 border-amber-800/80 text-amber-100'
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="font-bold text-white font-mono text-[11px]">{alert.id}</span>
                <span
                  className={`text-[9px] font-mono px-2 py-0.5 rounded font-extrabold uppercase ${
                    alert.severity === 'critical'
                      ? 'bg-red-900/80 text-red-200'
                      : 'bg-amber-900/80 text-amber-200'
                  }`}
                >
                  {alert.severity === 'critical' ? 'Kritik Eşik' : 'Uyarı'}
                </span>
              </div>

              <div className="font-semibold text-white text-xs">{alert.title}</div>
              {alert.message && (
                <p className="text-[11px] text-slate-300 leading-snug">{alert.message}</p>
              )}

              <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-[10px] font-mono">
                <span className="text-slate-400">
                  {new Date(alert.created_at).toLocaleTimeString('tr-TR')}
                </span>
                <div className="flex items-center gap-1.5">
                  <button
                    onClick={() => onAcknowledge(alert.id)}
                    className="px-2 py-0.5 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded text-[10px] cursor-pointer"
                  >
                    Onayla
                  </button>
                  <button
                    onClick={() => onCreateWorkOrderFromAlert(alert)}
                    className="px-2 py-0.5 bg-sky-900/80 hover:bg-sky-800 text-sky-200 rounded text-[10px] cursor-pointer flex items-center gap-1 font-sans font-bold"
                  >
                    <ClipboardPlus className="w-3 h-3" />
                    <span>İş Emri</span>
                  </button>
                  <button
                    onClick={() => onCloseAlert(alert.id)}
                    className="px-2 py-0.5 bg-emerald-900/80 hover:bg-emerald-800 text-emerald-200 rounded text-[10px] cursor-pointer"
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
  );
};
