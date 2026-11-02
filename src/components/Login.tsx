import React, { useState } from 'react';
import { login } from '../services/api';
import { ShieldCheck, Loader2 } from 'lucide-react';

export const Login: React.FC = () => {
  const [email, setEmail] = useState('admin@smartfarm.io');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await login(email, password);
      window.location.reload();
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Giriş başarısız.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex items-center justify-center min-h-screen bg-slate-950">
      <div className="w-full max-w-md p-8 bg-slate-900 rounded-2xl border border-slate-800 shadow-2xl">
        <div className="flex items-center justify-center mb-8">
          <ShieldCheck className="w-12 h-12 text-emerald-400" />
        </div>
        <h1 className="text-2xl font-bold text-white text-center mb-6">SmartFarm XR Admin</h1>
        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Email"
            className="w-full p-3 bg-slate-950 border border-slate-700 rounded-lg text-white"
          />
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Şifre"
            className="w-full p-3 bg-slate-950 border border-slate-700 rounded-lg text-white"
          />
          {error && <p className="text-red-400 text-sm text-center">{error}</p>}
          <button
            disabled={loading}
            className="w-full p-3 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg transition"
          >
            {loading ? <Loader2 className="w-5 h-5 animate-spin mx-auto" /> : 'Giriş Yap'}
          </button>
        </form>
      </div>
    </div>
  );
};
