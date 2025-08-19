// client/src/lib/api.ts
import { auth } from './firebase';

const API_BASE = import.meta.env.VITE_API_BASE ?? 'http://localhost:8080';

async function authFetch(path: string, opts: RequestInit = {}) {
  const user = auth.currentUser;
  if (!user) throw new Error('not_signed_in');
  const token = await user.getIdToken();
  const headers = new Headers(opts.headers || {});
  headers.set('Authorization', `Bearer ${token}`);
  headers.set('Content-Type', 'application/json');
  const res = await fetch(`${API_BASE}${path}`, { ...opts, headers });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw Object.assign(new Error(err.error || 'request_failed'), { details: err });
  }
  return res.json();
}

export const OrgsAPI = {
  create: (data: { name: string; invites?: { managers?: string[]; staff?: string[] } }) =>
    authFetch('/api/orgs', { method: 'POST', body: JSON.stringify(data) }),
  join: (orgId: string) =>
    authFetch('/api/orgs/join', { method: 'POST', body: JSON.stringify({ orgId }) }),
  me: () => authFetch('/api/orgs/me'),
};
