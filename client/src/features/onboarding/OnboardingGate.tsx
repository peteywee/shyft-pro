// client/src/features/onboarding/OnboardingGate.tsx
import { useEffect, useState } from 'react';
import { useAuth } from '../../lib/useAuth';
import { api } from '../../lib/api';

type Me = { uid: string; orgId?: string; role?: 'admin'|'manager'|'staff'; status?: 'pending'|'active'|'inactive' };

export default function OnboardingGate({ onReady }: { onReady?: (me: Me) => void }) {
  const { user, loading, idToken } = useAuth();
  const [me, setMe] = useState<Me | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      if (loading) return;
      if (!user) { setMe(null); return; }
      try {
        const token = await idToken();
        const resp = await api<Me>('/api/me', { idToken: token || undefined });
        setMe(resp);
        onReady?.(resp);
      } catch (e: any) {
        setError(e.message || String(e));
      }
    })();
  }, [user, loading]);

  if (loading) return <p>Loading...</p>;
  if (!user) return <p>Please sign in.</p>;
  if (error) return <p style={{ color: 'crimson' }}>{error}</p>;

  return <div><pre>{JSON.stringify(me, null, 2)}</pre></div>;
}
