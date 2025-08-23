// src/app/(app)/schedule-assistant/page.tsx
'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { auth, db } from '@/lib/firebase';
import { doc, getDoc } from 'firebase/firestore';

export default function ScheduleAssistantPage() {
  const router = useRouter();
  const [authorized, setAuthorized] = React.useState<boolean | null>(null);

  React.useEffect(() => {
    (async () => {
      const u = auth.currentUser;
      if (!u) { router.replace('/login'); return; }
      const snap = await getDoc(doc(db, 'users', u.uid));
      const data = snap.data();
      if (!data?.onboardingComplete) { router.replace('/onboarding'); return; }
      if (data?.role !== 'Admin') {
        alert('Access denied: Admins only.');
        router.replace('/dashboard');
        return;
      }
      setAuthorized(true);
    })();
  }, [router]);

  if (!authorized) return null;

  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold mb-4">AI Schedule Assistant</h1>
      {/* form that calls your Worker /api/schedule with auth token */}
    </main>
  );
}
