import { useState } from 'react';

export default function Punch() {
  const [busy, setBusy] = useState(false);
  const [last, setLast] = useState<'IN'|'OUT'|null>(null);

  const go = async () => {
    if (busy) return;
    setBusy(true);
    try {
      const type = last === 'IN' ? 'OUT' : 'IN';
      const res = await fetch('/api/punch', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ type })
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.error || 'Error');
      setLast(type);
      alert(`Recorded ${type} @ ${json.ts_server}`);
    } catch (e:any) {
      alert(e.message || 'Error');
    } finally {
      setBusy(false);
    }
  };

  return (
    <button onClick={go} disabled={busy} style={{ fontSize: 24, padding: 24 }}>
      {busy ? 'Working…' : (last === 'IN' ? 'Clock Out' : 'Clock In')}
    </button>
  );
}
