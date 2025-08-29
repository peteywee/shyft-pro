// src/app/(auth)/login/page.tsx
'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { signInWithEmailAndPassword, sendPasswordResetEmail, GoogleAuthProvider, signInWithRedirect, getRedirectResult } from 'firebase/auth';
import { auth } from '@/lib/firebase';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string|null>(null);

  React.useEffect(() => {
    // Handle Google redirect results if any
    getRedirectResult(auth).then((res) => {
      if (res?.user) {
        router.push('/dashboard');
      }
    }).catch((err) => setError(err?.message || 'Google sign-in failed.'));
  }, [router]);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (!email || !password) {
      setError('Email and password required.');
      return;
    }
    try {
      setLoading(true);
      await signInWithEmailAndPassword(auth, email, password);
      router.push('/dashboard');
    } catch (err: any) {
      setError(err?.message || 'Login failed.');
    } finally {
      setLoading(false);
    }
  };

  const onGoogle = () => {
    const provider = new GoogleAuthProvider();
    signInWithRedirect(auth, provider);
  };

  const onForgot = async () => {
    setError(null);
    if (!email) { setError('Enter your email to reset password.'); return; }
    try {
      await sendPasswordResetEmail(auth, email);
      alert(`Password reset link sent to ${email}`);
    } catch (err: any) {
      setError(err?.message || 'Reset failed.');
    }
  };

  return (
    <main className="max-w-md mx-auto p-6">
      <h1 className="text-2xl font-semibold mb-4">Sign in</h1>
      <form onSubmit={onSubmit} className="space-y-4">
        {error && <p className="text-red-600 text-sm">{error}</p>}
        <div>
          <label className="block text-sm">Email</label>
          <input type="email" className="w-full border p-2 rounded" value={email} onChange={e=>setEmail(e.target.value)} />
        </div>
        <div>
          <label className="block text-sm">Password</label>
          <input type="password" className="w-full border p-2 rounded" value={password} onChange={e=>setPassword(e.target.value)} />
        </div>
        <button disabled={loading} className="w-full bg-black text-white p-2 rounded">
          {loading ? 'Signing in...' : 'Sign in'}
        </button>
      </form>
      <button onClick={onGoogle} className="w-full mt-3 border p-2 rounded">Sign in with Google</button>
      <button onClick={onForgot} className="w-full mt-3 text-sm underline">Forgot password?</button>
    </main>
  );
}
