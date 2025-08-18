// client/src/features/onboarding/JoinOrg.tsx
import { useState } from 'react';
import { useAuth } from '../../lib/useAuth';
import { api } from '../../lib/api';

export default function JoinOrg() {
  const { idToken } = useAuth();
  const [orgId, setOrgId] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [error, setError] = useState<string|null>(null);
  const [ok, setOk] = useState(false);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null); setOk(false);
    try {
      const token = await idToken();
      await api(`/api/orgs/${encodeURIComponent(orgId)}/invites/accept`, {
        method: 'POST',
        idToken: token || undefined,
        body: JSON.stringify({ inviteCode })
      });
      setOk(true);
    } catch (e: any) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} style={{ maxWidth: 420, margin: '40px auto', display: 'grid', gap: 12 }}>
      <h2>Join an organization</h2>
      <input placeholder="Org ID" value={orgId} onChange={e=>setOrgId(e.target.value)} required />
      <input placeholder="Invite code" value={inviteCode} onChange={e=>setInviteCode(e.target.value)} required />
      {error && <div role="alert" style={{ color: 'crimson' }}>{error}</div>}
      <button disabled={busy} type="submit">{busy ? 'Joining...' : 'Join'}</button>
      {ok && <p>Success. Your role and status have been updated.</p>}
    </form>
  );
}
