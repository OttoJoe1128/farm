import React, { useState } from 'react';
import { ShieldCheck, Users, MapPin, History, UserPlus, Check, X, Search, ArrowLeft } from 'lucide-react';
import { UserAccount, AuditLogEntry, ParcelFeature } from '../types';

interface AdminPanelProps {
  parcels: ParcelFeature[];
  auditLogs: AuditLogEntry[];
  onBackToMap?: () => void;
}

export const AdminPanel: React.FC<AdminPanelProps> = ({ parcels, auditLogs, onBackToMap }) => {
  const [activeSubTab, setActiveSubTab] = useState<'users' | 'farms' | 'audit'>('users');
  const [searchTerm, setSearchTerm] = useState('');

  const [users, setUsers] = useState<UserAccount[]>([
    {
      id: 'usr_admin',
      username: 'admin',
      email: 'admin@smartfarm.io',
      role: 'superadmin',
      created_at: '2026-01-01T00:00:00Z',
      last_login: '2026-10-24T03:15:00Z',
    },
    {
      id: 'usr_operator1',
      username: 'ahmet.yilmaz',
      email: 'ahmet@smartfarm.io',
      role: 'operator',
      created_at: '2026-02-10T08:30:00Z',
      last_login: '2026-10-24T02:40:00Z',
    },
    {
      id: 'usr_agronomist',
      username: 'ayse.kaya',
      email: 'ayse.agronomy@smartfarm.io',
      role: 'operator',
      created_at: '2026-03-01T12:00:00Z',
      last_login: '2026-10-23T18:20:00Z',
    },
    {
      id: 'usr_viewer1',
      username: 'denetci.ali',
      email: 'ali.inspector@tarimorman.gov.tr',
      role: 'viewer',
      created_at: '2026-04-15T09:00:00Z',
      last_login: '2026-10-20T14:10:00Z',
    },
  ]);

  const [newUserModal, setNewUserModal] = useState(false);
  const [newUsername, setNewUsername] = useState('');
  const [newEmail, setNewEmail] = useState('');
  const [newRole, setNewRole] = useState<'admin' | 'operator' | 'viewer'>('operator');

  const handleAddUser = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newUsername || !newEmail) return;
    const created: UserAccount = {
      id: `usr_${Date.now()}`,
      username: newUsername,
      email: newEmail,
      role: newRole,
      created_at: new Date().toISOString(),
    };
    setUsers([...users, created]);
    setNewUsername('');
    setNewEmail('');
    setNewUserModal(false);
  };

  const handleRoleChange = (userId: string, newRole: UserAccount['role']) => {
    setUsers(users.map((u) => (u.id === userId ? { ...u, role: newRole } : u)));
  };

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
              <ShieldCheck className="w-6 h-6 text-emerald-400" />
              <span>Sistem & Admin Yönetim Paneli</span>
            </h1>
            <p className="text-xs text-slate-400 mt-1">
              Kullanıcı yetkilendirmeleri (RBAC), çiftlik/parsel kütükleri ve sistemsel denetim günlükleri (Audit Log).
            </p>
          </div>
        </div>

        {/* Sub Navigation */}
        <div className="flex items-center gap-1 p-1 bg-slate-900 border border-slate-800 rounded-lg text-xs">
          <button
            onClick={() => setActiveSubTab('users')}
            className={`px-3 py-1.5 rounded-md font-medium transition-colors cursor-pointer flex items-center gap-1.5 ${
              activeSubTab === 'users' ? 'bg-slate-800 text-white shadow-sm' : 'text-slate-400 hover:text-white'
            }`}
          >
            <Users className="w-3.5 h-3.5" />
            <span>Kullanıcılar</span>
          </button>
          <button
            onClick={() => setActiveSubTab('farms')}
            className={`px-3 py-1.5 rounded-md font-medium transition-colors cursor-pointer flex items-center gap-1.5 ${
              activeSubTab === 'farms' ? 'bg-slate-800 text-white shadow-sm' : 'text-slate-400 hover:text-white'
            }`}
          >
            <MapPin className="w-3.5 h-3.5" />
            <span>Çiftlikler & Parseller</span>
          </button>
          <button
            onClick={() => setActiveSubTab('audit')}
            className={`px-3 py-1.5 rounded-md font-medium transition-colors cursor-pointer flex items-center gap-1.5 ${
              activeSubTab === 'audit' ? 'bg-slate-800 text-white shadow-sm' : 'text-slate-400 hover:text-white'
            }`}
          >
            <History className="w-3.5 h-3.5" />
            <span>Denetim Günlüğü</span>
          </button>
        </div>
      </div>

      {/* Users Subtab */}
      {activeSubTab === 'users' && (
        <div className="mt-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-white">Sistem Kullanıcıları ve Yetki Rolleri</h2>
            <button
              onClick={() => setNewUserModal(true)}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold rounded-lg cursor-pointer"
            >
              <UserPlus className="w-3.5 h-3.5" />
              <span>Yeni Kullanıcı Ekle</span>
            </button>
          </div>

          <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden shadow-xl">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-slate-800 bg-slate-950/60 text-slate-400">
                  <th className="py-3 px-4">Kullanıcı Adı</th>
                  <th className="py-3 px-4">E-Posta</th>
                  <th className="py-3 px-4">Sistem Rolü</th>
                  <th className="py-3 px-4">Kayıt Tarihi</th>
                  <th className="py-3 px-4">Son Giriş</th>
                  <th className="py-3 px-4 text-right">Rol Değiştir</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 font-sans">
                {users.map((u) => (
                  <tr key={u.id} className="hover:bg-slate-800/30">
                    <td className="py-3 px-4 font-bold text-slate-100">{u.username}</td>
                    <td className="py-3 px-4 text-slate-300 font-mono">{u.email}</td>
                    <td className="py-3 px-4">
                      <span className="font-mono text-xs font-semibold uppercase text-emerald-400">
                        {u.role}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-slate-400 font-mono tabular-nums">
                      {new Date(u.created_at).toLocaleDateString('tr-TR')}
                    </td>
                    <td className="py-3 px-4 text-slate-400 font-mono tabular-nums">
                      {u.last_login ? new Date(u.last_login).toLocaleTimeString('tr-TR') : '-'}
                    </td>
                    <td className="py-3 px-4 text-right">
                      {u.role !== 'superadmin' && (
                        <select
                          aria-label="Rol Seç"
                          value={u.role}
                          onChange={(e) => handleRoleChange(u.id, e.target.value as UserAccount['role'])}
                          className="bg-slate-800 border border-slate-700 text-slate-200 text-xs rounded px-2 py-1 cursor-pointer"
                        >
                          <option value="admin">Admin</option>
                          <option value="operator">Operator</option>
                          <option value="viewer">Viewer</option>
                        </select>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Farms Subtab */}
      {activeSubTab === 'farms' && (
        <div className="mt-6 space-y-4">
          <h2 className="text-sm font-bold text-white">Sistemde Kayıtlı Kadastro Parselleri ({parcels.length})</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {parcels.map((p, idx) => (
              <div key={idx} className="bg-slate-900 border border-slate-800 rounded-xl p-5 shadow-lg flex flex-col gap-2">
                <div className="flex items-center justify-between">
                  <h3 className="font-bold text-white text-sm">
                    {p.properties.name || `Parsel ${p.properties.ParselNo}`}
                  </h3>
                  <span className="text-xs font-mono text-emerald-400 bg-emerald-950/60 border border-emerald-800/40 px-2 py-0.5 rounded">
                    {p.properties.Alan}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2 text-xs text-slate-300 font-sans mt-2">
                  <div>İl / İlçe: <strong className="text-white">{p.properties.Il} / {p.properties.Ilce}</strong></div>
                  <div>Mahalle: <strong className="text-white">{p.properties.Mahalle || '-'}</strong></div>
                  <div>Ada / Parsel: <strong className="text-white">{p.properties.Ada || '-'}/{p.properties.ParselNo}</strong></div>
                  <div>Nitelik: <strong className="text-white">{p.properties.Nitelik}</strong></div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Audit Log Subtab */}
      {activeSubTab === 'audit' && (
        <div className="mt-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-white">Sistem & Varlık Değişiklik Günlüğü (Audit Trail)</h2>
            <div className="relative">
              <Search className="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-slate-500" />
              <input
                type="text"
                placeholder="Olay veya kullanıcı ara..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="bg-slate-900 border border-slate-800 rounded-lg pl-8 pr-3 py-1.5 text-xs text-slate-200 focus:outline-none focus:ring-1 focus:ring-emerald-500"
              />
            </div>
          </div>

          <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden shadow-xl max-h-96 overflow-y-auto">
            <table className="w-full text-left border-collapse text-xs font-mono">
              <thead>
                <tr className="border-b border-slate-800 bg-slate-950/60 text-slate-400">
                  <th className="py-2.5 px-4">Tarih / Saat</th>
                  <th className="py-2.5 px-4">Kullanıcı</th>
                  <th className="py-2.5 px-4">Olay Adı (Event)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/50">
                {auditLogs
                  .filter((l) => l.event.toLowerCase().includes(searchTerm.toLowerCase()) || (l.user || '').toLowerCase().includes(searchTerm.toLowerCase()))
                  .map((log, idx) => (
                    <tr key={idx} className="hover:bg-slate-800/30">
                      <td className="py-2 px-4 text-slate-400">{new Date(log.at).toLocaleString('tr-TR')}</td>
                      <td className="py-2 px-4 text-emerald-400">{log.user || 'system'}</td>
                      <td className="py-2 px-4 text-slate-200">{log.event}</td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Modal: New User */}
      {newUserModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
          <div className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl">
            <h3 className="text-base font-bold text-white mb-4">Yeni Kullanıcı Hesabı Ekle</h3>
            <form onSubmit={handleAddUser} className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-300 font-medium mb-1">Kullanıcı Adı</label>
                <input
                  type="text"
                  required
                  value={newUsername}
                  onChange={(e) => setNewUsername(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">E-Posta</label>
                <input
                  type="email"
                  required
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                />
              </div>
              <div>
                <label className="block text-slate-300 font-medium mb-1">Yetki Rolü</label>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value as any)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-slate-100"
                >
                  <option value="operator">Operator (Varlık & İş Emri Yönetimi)</option>
                  <option value="admin">Admin (Tam Yönetim)</option>
                  <option value="viewer">Viewer (Salt Okunur)</option>
                </select>
              </div>
              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setNewUserModal(false)}
                  className="px-4 py-2 text-slate-400 hover:text-white cursor-pointer"
                >
                  İptal
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg cursor-pointer"
                >
                  Kullanıcıyı Kaydet
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
