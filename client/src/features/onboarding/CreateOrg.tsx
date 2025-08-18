// client/src/features/onboarding/CreateOrg.tsx
import { useState } from 'react';
import { useAuth } from '../../lib/useAuth';
import { api } from '../../lib/api';

export default function CreateOrg() {
  const { idToken } = useAuth();
  const [name, setName] = useState('');
  const [error, setError] = useState<string|null>(null);
  const [orgId, setOrgId] = useState<string| null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null);
    try {
      const token = await idToken();
      const resp = await api<{ orgId: string }>('/api/orgs', {
        method: 'POST',
        idToken: token || undefined,
        body: JSON.stringify({ name })
      });
      setOrgId(resp.orgId);
    } catch (e: any) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} style={{ maxWidth: 420, margin: '40px auto', display: 'grid', gap: 12 }}>
      <h2>Create your organization</h2>
      <input placeholder="Organization name" value={name} onChange={e=>setName(e.target.value)} required />
      {error && <div role="alert" style={{ color: 'crimson' }}>{error}</div>}
      <button disabled={busy} type="submit">{busy ? 'Creating...' : 'Create org'}</button>
      {orgId && <p>Created org <b>{orgId}</b>. You can now invite managers and staff.</p>}
    </form>
  );
}
