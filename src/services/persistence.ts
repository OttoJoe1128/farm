import { CanonicalAsset, ParcelFeature, WorkOrder } from '../types';

export const STORAGE_KEY = 'smartfarm_state_v2';
const BACKUP_MARKER = 'smartfarm_backup';

export interface PersistedState {
  assets: CanonicalAsset[];
  workOrders: WorkOrder[];
  parcels: ParcelFeature[];
}

export type SaveResult = { ok: true } | { ok: false; reason: 'quota' | 'unknown'; error: unknown };

export function loadState(): Partial<PersistedState> | null {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return null;
    const parsed = JSON.parse(saved);
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch (e) {
    console.warn('LocalStorage error:', e);
    return null;
  }
}

function isQuotaError(error: unknown): boolean {
  if (!(error instanceof DOMException)) return false;
  return (
    error.name === 'QuotaExceededError' ||
    error.name === 'NS_ERROR_DOM_QUOTA_REACHED' ||
    error.code === 22 ||
    error.code === 1014
  );
}

export function saveState(state: PersistedState): SaveResult {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    return { ok: true };
  } catch (error) {
    console.warn('LocalStorage save error:', error);
    return { ok: false, reason: isQuotaError(error) ? 'quota' : 'unknown', error };
  }
}

export function buildBackup(state: PersistedState): string {
  return JSON.stringify(
    {
      [BACKUP_MARKER]: 1,
      exported_at: new Date().toISOString(),
      assets: state.assets,
      workOrders: state.workOrders,
      parcels: state.parcels,
    },
    null,
    2
  );
}

/** Yedek dosyası değilse null döner (normal GeoJSON akışı devam eder). */
export function parseBackup(text: string): PersistedState | null {
  try {
    const json = JSON.parse(text.replace(/^\uFEFF/, ''));
    if (!json || json[BACKUP_MARKER] !== 1) return null;
    if (!Array.isArray(json.assets) || !Array.isArray(json.workOrders) || !Array.isArray(json.parcels)) return null;
    return { assets: json.assets, workOrders: json.workOrders, parcels: json.parcels };
  } catch {
    return null;
  }
}
