// src/app/(auth)/signup/page.tsx
'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { createUserWithEmailAndPassword } from 'firebase/auth';
import { doc, setDoc } from 'firebase/firestore';
import { auth, db } from '@/lib/firebase';

const DEV_ALLOWED = ['cravenwspatrick@gmail.com']; // dev-only allowlist

export default function SignupPage() {
  const router = useRouter();
  const [name, setName] = React.useState('');
  const [email, setEmail] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [inviteCode, setInviteCode] = React.useState(''); // prod: require invite

  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!name || !email || !password) {
      setError('All fields are required.');
      return;
    }

    // DEV gating: only whitelisted emails can sign up
    if (process.env.NODE_ENV !== 'production' && !DEV_ALLOWED.includes(email)) {
      setError('Sign-ups restricted during development.');
      return;
    }

    // PROD idea: validate inviteCode via Worker/Fn before account creation
    // (left as client placeholder; you can enforce server-side too)

    try {
      setLoading(true);
      const cred = await createUserWithEmailAndPassword(auth, email, password);
      await setDoc(doc(db, 'users', cred.user.uid), {
        name,
        email,
        role: null,            // set in organization-setup
        orgId: null,          // set in organization-setup
        onboardingComplete: false,
        createdAt: Date.now(),
      });
      router.push('/organization-setup');
    } catch (err: any) {
      setError(err?.message || 'Signup failed.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="max-w-md mx-auto p-6">
      <h1 className="text-2xl font-semibold mb-4">Create your account</h1>
      <form onSubmit={onSubmit} className="space-y-4">
        {error && <p className="text-red-600 text-sm">{error}</p>}
        <div>
          <label className="block text-sm">Full name</label>
          <input className="w-full border p-2 rounded" value={name} onChange={e=>setName(e.target.value)} />
        </div>
        <div>
          <label className="block text-sm">Email</label>
          <input type="email" className="w-full border p-2 rounded" value={email} onChange={e=>setEmail(e.target.value)} />
        </div>
        <div>
          <label className="block text-sm">Password</label>
          <input type="password" className="w-full border p-2 rounded" value={password} onChange={e=>setPassword(e.target.value)} />
        </div>
        {/* Optional: invite code for production */}
        <div>
          <label className="block text-sm">Invitation Code (required in prod)</label>
          <input className="w-full border p-2 rounded" value={inviteCode} onChange={e=>setInviteCode(e.target.value)} />
        </div>
        <button disabled={loading} className="w-full bg-black text-white p-2 rounded">
          {loading ? 'Creating...' : 'Sign up'}
        </button>
      </form>
    </main>
  );
}
