import React, { useState } from 'react';
import { ClipboardList, Plus, CheckCircle, Clock, AlertTriangle, User, Calendar, Tag, Filter, ArrowLeft } from 'lucide-react';
import { WorkOrder, WorkOrderPriority, WorkOrderStatus, CanonicalAsset } from '../types';

interface WorkOrdersPanelProps {
  workOrders: WorkOrder[];
  assets: CanonicalAsset[];
  onAddWorkOrder: (order: Omit<WorkOrder, 'work_order_id' | 'created_at'>) => void;
  onUpdateStatus: (workOrderId: string, status: WorkOrderStatus) => void;
  onBackToMap?: () => void;
}

export const WorkOrdersPanel: React.FC<WorkOrdersPanelProps> = ({
  workOrders,
  assets,
  onAddWorkOrder,
  onUpdateStatus,
  onBackToMap,
}) => {
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [priorityFilter, setPriorityFilter] = useState<string>('all');
  const [showCreateModal, setShowCreateModal] = useState<boolean>(false);

  // Form State
  const [selectedAssetId, setSelectedAssetId] = useState<string>(assets[0]?.asset_id || '');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [assignee, setAssignee] = useState('Ahmet Yılmaz (Saha Teknisyeni)');
  const [priority, setPriority] = useState<WorkOrderPriority>('normal');
  const [dueAt, setDueAt] = useState('');

  const filteredOrders = workOrders.filter((order) => {
    if (statusFilter !== 'all' && order.status !== statusFilter) return false;
    if (priorityFilter !== 'all' && order.priority !== priorityFilter) return false;
    return true;
  });

  const handleCreateSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const matchedAsset = assets.find((a) => a.asset_id === selectedAssetId);
    onAddWorkOrder({
      asset_id: selectedAssetId,
      asset_name: matchedAsset?.name || 'Genel Saha',
      title,
      description,
      assignee,
      priority,
      status: 'bekliyor',
      due_at: dueAt || undefined,
    });

    setTitle('');
    setDescription('');
    setShowCreateModal(false);
  };

  const getPriorityBadge = (p: WorkOrderPriority) => {
    switch (p) {
      case 'acil':
        return <span className="text-red-400 font-semibold font-mono">ACİL</span>;
      case 'yuksek':
        return <span className="text-amber-400 font-semibold font-mono">YÜKSEK</span>;
      case 'normal':
        return <span className="text-sky-400 font-medium font-mono">NORMAL</span>;
      default:
        return <span className="text-slate-400 font-mono">DÜŞÜK</span>;
    }
  };

  const getStatusBadge = (s: WorkOrderStatus) => {
    switch (s) {
      case 'tamamlandi':
        return (
          <span className="inline-flex items-center gap-1.5 text-emerald-400 font-medium">
            <CheckCircle className="w-3.5 h-3.5" />
            <span>Tamamlandı</span>
          </span>
        );
      case 'devam_ediyor':
        return (
          <span className="inline-flex items-center gap-1.5 text-amber-400 font-medium">
            <Clock className="w-3.5 h-3.5" />
            <span>Devam Ediyor</span>
          </span>
        );
      case 'iptal':
        return <span className="text-slate-500">İptal Edildi</span>;
      default:
        return (
          <span className="inline-flex items-center gap-1.5 text-sky-400 font-medium">
            <AlertTriangle className="w-3.5 h-3.5" />
            <span>Bekliyor</span>
          </span>
        );
    }
  };

  return (
    <div className="w-full h-full flex flex-col p-8 overflow-y-auto bg-slate-950 select-none">
      {/* Header and Controls */}
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
              <ClipboardList className="w-6 h-6 text-emerald-400" />
              <span>Saha ve Bakım İş Emirleri</span>
            </h1>
            <p className="text-xs text-slate-400 mt-1">
              Çiftlik varlıkları için planlanan sulama, gübreleme, sensör onarımı ve denetim görevleri.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {/* Status Filter */}
          <div className="flex items-center gap-1 p-1 bg-slate-900 border border-slate-800 rounded-lg text-xs">
            <button
              onClick={() => setStatusFilter('all')}
              className={`px-3 py-1.5 rounded-md font-medium transition-colors cursor-pointer ${
                statusFilter === 'all' ? 'bg-slate-800 text-white shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              Tümü
            </button>
            <button
              onClick={() => setStatusFilter('bekliyor')}
              className={`px-3 py-1.5 rounded-md font-medium transition-colors cursor-pointer ${
                statusFilter === 'bekliyor' ? 'bg-slate-800 text-sky-400 shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              Bekleyen
            </button>
            <button
              onClick={() => setStatusFilter('devam_ediyor')}
              className={`px-3 py-1.5 rounded-md font-medium transition-colors cursor-pointer ${
                statusFilter === 'devam_ediyor' ? 'bg-slate-800 text-amber-400 shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              Devam Eden
            </button>
            <button
              onClick={() => setStatusFilter('tamamlandi')}
              className={`px-3 py-1.5 rounded-md font-medium transition-colors cursor-pointer ${
                statusFilter === 'tamamlandi' ? 'bg-slate-800 text-emerald-400 shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              Tamamlanan
            </button>
          </div>

          {/* New Work Order Button */}
          <button
            onClick={() => setShowCreateModal(true)}
            className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold rounded-lg transition-colors cursor-pointer shadow-md shadow-emerald-900/40"
          >
            <Plus className="w-4 h-4" />
            <span>Yeni İş Emri</span>
          </button>
        </div>
      </div>

      {/* Orders Table */}
      <div className="mt-6 flex-1 bg-slate-900/80 border border-slate-800 rounded-xl overflow-hidden shadow-xl flex flex-col">
        <div className="overflow-x-auto flex-1">
          <table className="w-full text-left border-collapse text-xs">
            <thead>
              <tr className="border-b border-slate-800 bg-slate-950/60 text-slate-400 font-medium">
                <th className="py-3 px-4">İş Emri No</th>
                <th className="py-3 px-4">İlgili Varlık</th>
                <th className="py-3 px-4">Başlık & Görev Tanımı</th>
                <th className="py-3 px-4">Atanan Kişi</th>
                <th className="py-3 px-4">Öncelik</th>
                <th className="py-3 px-4">Son Tarih</th>
                <th className="py-3 px-4">Durum</th>
                <th className="py-3 px-4 text-right">Eylem</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 font-sans">
              {filteredOrders.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-slate-500">
                    Kayıtlı veya kriterlere uyan iş emri bulunamadı.
                  </td>
                </tr>
              ) : (
                filteredOrders.map((order) => (
                  <tr key={order.work_order_id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-3.5 px-4 font-mono font-bold text-slate-300">
                      {order.work_order_id}
                    </td>
                    <td className="py-3.5 px-4 text-slate-200">
                      <div className="font-semibold text-white">{order.asset_name || 'Genel Varlık'}</div>
                      <div className="text-[11px] text-slate-400 font-mono">{order.asset_id}</div>
                    </td>
                    <td className="py-3.5 px-4 max-w-sm">
                      <div className="font-medium text-slate-200">{order.title}</div>
                      {order.description && (
                        <div className="text-slate-400 text-[11px] truncate mt-0.5">{order.description}</div>
                      )}
                    </td>
                    <td className="py-3.5 px-4 text-slate-300 font-medium">
                      {order.assignee || 'Atanmadı'}
                    </td>
                    <td className="py-3.5 px-4">
                      {getPriorityBadge(order.priority)}
                    </td>
                    <td className="py-3.5 px-4 font-mono text-slate-400 tabular-nums">
                      {order.due_at ? new Date(order.due_at).toLocaleDateString('tr-TR') : '-'}
                    </td>
                    <td className="py-3.5 px-4">
                      {getStatusBadge(order.status)}
                    </td>
                    <td className="py-3.5 px-4 text-right">
                      <select
                        aria-label="Durumu Değiştir"
                        value={order.status}
                        onChange={(e) => onUpdateStatus(order.work_order_id, e.target.value as WorkOrderStatus)}
                        className="bg-slate-800 border border-slate-700 text-slate-200 text-xs rounded px-2 py-1 cursor-pointer focus:ring-1 focus:ring-emerald-500"
                      >
                        <option value="bekliyor">Bekliyor</option>
                        <option value="devam_ediyor">Devam Ediyor</option>
                        <option value="tamamlandi">Tamamlandı</option>
                        <option value="iptal">İptal</option>
                      </select>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal: Create Work Order */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
          <div className="w-full max-w-lg bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl">
            <h3 className="text-base font-bold text-white mb-4 flex items-center gap-2">
              <Plus className="w-5 h-5 text-emerald-400" />
              <span>Yeni İş Emri Oluştur</span>
            </h3>

            <form onSubmit={handleCreateSubmit} className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-300 font-medium mb-1">Hedef Varlık</label>
                <select
                  value={selectedAssetId}
                  onChange={(e) => setSelectedAssetId(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-200"
                >
                  {assets.map((a) => (
                    <option key={a.asset_id} value={a.asset_id}>
                      {a.name} ({a.properties.digital_card?.genel?.asset_code || a.asset_id})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">İş Emri Başlığı *</label>
                <input
                  type="text"
                  required
                  placeholder="Örn: Sensör Batarya Değişimi veya Damla Sulama Kontrolü"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100 focus:outline-none focus:ring-1 focus:ring-emerald-500"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">Açıklama & Detaylar</label>
                <textarea
                  rows={3}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Atanan Personel</label>
                  <input
                    type="text"
                    value={assignee}
                    onChange={(e) => setAssignee(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Öncelik Derecesi</label>
                  <select
                    value={priority}
                    onChange={(e) => setPriority(e.target.value as WorkOrderPriority)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                  >
                    <option value="dusuk">Düşük</option>
                    <option value="normal">Normal</option>
                    <option value="yuksek">Yüksek</option>
                    <option value="acil">Acil</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">Son Tamamlanma Tarihi</label>
                <input
                  type="date"
                  value={dueAt}
                  onChange={(e) => setDueAt(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2 text-slate-400 hover:text-white cursor-pointer"
                >
                  İptal
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg cursor-pointer shadow-md shadow-emerald-900/40"
                >
                  İş Emrini Kaydet
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
