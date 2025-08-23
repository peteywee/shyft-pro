// src/app/(app)/dashboard/page.tsx
'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { auth, db } from '@/lib/firebase';
import { doc, getDoc } from 'firebase/firestore';

export default function DashboardPage() {
  const router = useRouter();
  const [ready, setReady] = React.useState(false);

  React.useEffect(() => {
    (async () => {
      const u = auth.currentUser;
      if (!u) { router.replace('/login'); return; }
      const snap = await getDoc(doc(db, 'users', u.uid));
      const data = snap.data();
      if (!data?.onboardingComplete) {
        router.replace('/onboarding');
        return;
      }
      setReady(true);
    })();
  }, [router]);

  if (!ready) return null;

  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold">Dashboard</h1>
      {/* TODO: render real data instead of mocks, scoped by user.orgId */}
    </main>
  );
}
