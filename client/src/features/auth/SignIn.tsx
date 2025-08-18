// client/src/features/auth/SignIn.tsx
import { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../../lib/firebase';

export default function SignIn({ onSignedIn }: { onSignedIn?: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null);
    try {
      await signInWithEmailAndPassword(auth, email, password);
      onSignedIn?.();
    } catch (err: any) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} style={{ maxWidth: 360, margin: '40px auto', display: 'grid', gap: 12 }}>
      <h2>Sign in</h2>
      <input placeholder="email" type="email" value={email} onChange={e=>setEmail(e.target.value)} required />
      <input placeholder="password" type="password" value={password} onChange={e=>setPassword(e.target.value)} required />
      {error && <div role="alert" style={{ color: 'crimson' }}>{error}</div>}
      <button disabled={busy} type="submit">{busy ? 'Signing in...' : 'Sign in'}</button>
    </form>
  );
}
