// client/src/features/auth/SignUp.tsx
import { useState } from 'react';
import { createUserWithEmailAndPassword, updateProfile } from 'firebase/auth';
import { auth } from '../../lib/firebase';

export default function SignUp({ onSignedUp }: { onSignedUp?: () => void }) {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null);
    try {
      const cred = await createUserWithEmailAndPassword(auth, email, password);
      await updateProfile(cred.user, { displayName: [firstName, lastName].filter(Boolean).join(' ') });
      onSignedUp?.();
    } catch (err: any) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} style={{ maxWidth: 420, margin: '40px auto', display: 'grid', gap: 12 }}>
      <h2>Create your account</h2>
      <div style={{ display:'grid', gap:8, gridTemplateColumns:'1fr 1fr' }}>
        <input placeholder="first name" value={firstName} onChange={e=>setFirstName(e.target.value)} required />
        <input placeholder="last name" value={lastName} onChange={e=>setLastName(e.target.value)} required />
      </div>
      <input placeholder="email" type="email" value={email} onChange={e=>setEmail(e.target.value)} required />
      <input placeholder="password" type="password" value={password} onChange={e=>setPassword(e.target.value)} required />
      {error && <div role="alert" style={{ color: 'crimson' }}>{error}</div>}
      <button disabled={busy} type="submit">{busy ? 'Creating...' : 'Create account'}</button>
    </form>
  );
}
