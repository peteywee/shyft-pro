// src/app/(auth)/organization-setup/page.tsx
'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { auth, db } from '@/lib/firebase';
import { addDoc, collection, doc, getDoc, updateDoc } from 'firebase/firestore';

export default function OrganizationSetupPage() {
  const router = useRouter();
  const [inviteCode, setInviteCode] = React.useState('');
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string|null>(null);

  const onCreateOrg = async () => {
    setError(null);
    const user = auth.currentUser;
    if (!user) { setError('Not authenticated.'); return; }

    try {
      setLoading(true);
      const orgRef = await addDoc(collection(db, 'organizations'), {
        name: `${user.email?.split('@')[0]}'s Workspace`,
        ownerUid: user.uid,
        createdAt: Date.now(),
      });

      await updateDoc(doc(db, 'users', user.uid), {
        role: 'Admin',
        orgId: orgRef.id,
      });

      router.push('/onboarding');
    } catch (err: any) {
      setError(err?.message || 'Failed to create organization.');
    } finally {
      setLoading(false);
    }
  };

  const onJoinOrg = async () => {
    setError(null);
    const user = auth.currentUser;
    if (!user) { setError('Not authenticated.'); return; }
    if (!inviteCode) { setError('Invitation code required.'); return; }

    try {
      setLoading(true);
      // Minimal client-side join logic (you can move this to Worker for more security)
      const inviteSnap = await getDoc(doc(db, 'invites', inviteCode));
      if (!inviteSnap.exists()) throw new Error('Invalid invite code.');

      const { orgId, role = 'Staff', used = false } = inviteSnap.data() || {};
      if (used) throw new Error('Invite already used.');

      await updateDoc(doc(db, 'users', user.uid), { role, orgId });
      await updateDoc(doc(db, 'invites', inviteCode), { used: true, usedBy: user.uid, usedAt: Date.now() });

      router.push('/onboarding');
    } catch (err: any) {
      setError(err?.message || 'Failed to join organization.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="max-w-md mx-auto p-6">
      <h1 className="text-2xl font-semibold mb-4">Organization Setup</h1>
      {error && <p className="text-red-600 text-sm mb-3">{error}</p>}
      <div className="space-y-3">
        <button disabled={loading} onClick={onCreateOrg} className="w-full bg-black text-white p-2 rounded">
          {loading ? 'Working...' : 'Create a new organization (Admin)'}
        </button>
        <div className="border rounded p-3 space-y-2">
          <label className="block text-sm">Invitation Code</label>
          <input className="w-full border p-2 rounded" value={inviteCode} onChange={e=>setInviteCode(e.target.value)} />
          <button disabled={loading} onClick={onJoinOrg} className="w-full border p-2 rounded">
            Join existing organization (Staff)
          </button>
        </div>
      </div>
    </main>
  );
}
