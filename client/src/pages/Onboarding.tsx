// client/src/pages/Onboarding.tsx
import { useEffect, useState } from 'react';
import { OrgsAPI } from '../lib/api';

function parseEmails(s: string): string[] {
  return s
    .split(',')
    .map((e) => e.trim())
    .filter(Boolean);
}

export default function Onboarding() {
  const [mode, setMode] = useState<'create' | 'join'>('create');

  // CREATE
  const [orgName, setOrgName] = useState('');
  const [mgrs, setMgrs] = useState('');
  const [staff, setStaff] = useState('');
  const [createBusy, setCreateBusy] = useState(false);
  const [createMsg, setCreateMsg] = useState<string | null>(null);

  // JOIN
  const [orgId, setOrgId] = useState('');
  const [joinBusy, setJoinBusy] = useState(false);
  const [joinMsg, setJoinMsg] = useState<string | null>(null);

  // Me
  const [summary, setSummary] = useState<{ orgId: string; name: string; role: string } | null>(
    null,
  );

  useEffect(() => {
    OrgsAPI.me()
      .then(setSummary)
      .catch(() => setSummary(null));
  }, []);

  const createOrg = async () => {
    setCreateBusy(true);
    setCreateMsg(null);
    try {
      const invites = {
        managers: parseEmails(mgrs),
        staff: parseEmails(staff),
      };
      const res = await OrgsAPI.create({
        name: orgName.trim(),
        invites,
      });
      setCreateMsg(`Created org ${res.name} (${res.orgId}). You are admin.`);
      setSummary({ orgId: res.orgId, name: res.name, role: 'admin' });
    } catch (e: any) {
      setCreateMsg(`Error: ${e?.details?.error || e.message}`);
    } finally {
      setCreateBusy(false);
    }
  };

  const joinOrg = async () => {
    setJoinBusy(true);
    setJoinMsg(null);
    try {
      const res = await OrgsAPI.join(orgId.trim());
      setJoinMsg(`Joined org ${res.orgId} as ${res.role}.`);
      const me = await OrgsAPI.me();
      setSummary(me);
    } catch (e: any) {
      setJoinMsg(`Error: ${e?.details?.error || e.message}`);
    } finally {
      setJoinBusy(false);
    }
  };

  return (
    <div style={{ maxWidth: 720, margin: '40px auto', padding: 16 }}>
      <h1>Onboarding</h1>

      {summary && (
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, marginBottom: 16 }}>
          <strong>Current:</strong> {summary.name} ({summary.orgId}) — role: {summary.role}
        </div>
      )}

      <div style={{ display: 'flex', gap: 12, marginBottom: 16 }}>
        <button
          onClick={() => setMode('create')}
          style={{ padding: 8, fontWeight: mode === 'create' ? 700 : 400 }}
        >
          Create Org
        </button>
        <button
          onClick={() => setMode('join')}
          style={{ padding: 8, fontWeight: mode === 'join' ? 700 : 400 }}
        >
          Join Org
        </button>
      </div>

      {mode === 'create' ? (
        <div style={{ border: '1px solid #eee', borderRadius: 8, padding: 16 }}>
          <h2>Create an Organization</h2>
          <label>
            Org name
            <input
              value={orgName}
              onChange={(e) => setOrgName(e.target.value)}
              placeholder="Acme Widgets"
              style={{ display: 'block', width: '100%', marginTop: 4, marginBottom: 12 }}
            />
          </label>

          <label>
            Invite managers (emails, comma-separated)
            <input
              value={mgrs}
              onChange={(e) => setMgrs(e.target.value)}
              placeholder="alice@acme.com,bob@acme.com"
              style={{ display: 'block', width: '100%', marginTop: 4, marginBottom: 12 }}
            />
          </label>

          <label>
            Invite staff (emails, comma-separated)
            <input
              value={staff}
              onChange={(e) => setStaff(e.target.value)}
              placeholder="carol@acme.com,dave@acme.com"
              style={{ display: 'block', width: '100%', marginTop: 4, marginBottom: 12 }}
            />
          </label>

          <button disabled={createBusy || !orgName.trim()} onClick={createOrg}>
            {createBusy ? 'Creating…' : 'Create Organization'}
          </button>

          {createMsg && <p style={{ marginTop: 12 }}>{createMsg}</p>}
        </div>
      ) : (
        <div style={{ border: '1px solid #eee', borderRadius: 8, padding: 16 }}>
          <h2>Join an Organization</h2>
          <label>
            Org ID
            <input
              value={orgId}
              onChange={(e) => setOrgId(e.target.value)}
              placeholder="paste orgId you were invited to"
              style={{ display: 'block', width: '100%', marginTop: 4, marginBottom: 12 }}
            />
          </label>

          <button disabled={joinBusy || !orgId.trim()} onClick={joinOrg}>
            {joinBusy ? 'Joining…' : 'Join Organization'}
          </button>

          {joinMsg && <p style={{ marginTop: 12 }}>{joinMsg}</p>}
        </div>
      )}
    </div>
  );
}
