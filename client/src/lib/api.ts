// client/src/lib/api.ts
export async function api<T = any>(path: string, opts: RequestInit & { idToken?: string|null } = {}): Promise<T> {
  const { idToken, headers, ...rest } = opts;
  const res = await fetch(path, {
    ...rest,
    headers: {
      'Content-Type': 'application/json',
      ...(headers || {}),
      ...(idToken ? { 'Authorization': `Bearer ${idToken}` } : {}),
    }
  });
  if (!res.ok) {
    let msg = await res.text();
    try { const j = JSON.parse(msg); msg = (j.error || msg); } catch {}
    throw new Error(`${res.status} ${res.statusText}: ${msg}`);
  }
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) return res.json() as Promise<T>;
  // @ts-ignore
  return res.text() as Promise<T>;
}
