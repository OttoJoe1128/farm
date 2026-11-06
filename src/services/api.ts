import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: API_URL,
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config: any) => {
  const token = localStorage.getItem('auth_token');
  if (token && config.headers) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export const login = async (email: string, password: string) => {
  const response = await api.post('/api/v1/auth/login', { email, password });
  const { access_token } = response.data;
  localStorage.setItem('auth_token', access_token);
  return response.data;
};

export const logout = () => {
  localStorage.removeItem('auth_token');
  window.location.reload();
};

export default api;
