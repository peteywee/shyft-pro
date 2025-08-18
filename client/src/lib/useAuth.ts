// client/src/lib/useAuth.ts
import { useEffect, useState } from 'react';
import { onAuthStateChanged, User, getIdToken } from 'firebase/auth';
import { auth } from './firebase';

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    return onAuthStateChanged(auth, async (u) => {
      setUser(u);
      setLoading(false);
    });
  }, []);

  async function idToken(): Promise<string|null> {
    if (!auth.currentUser) return null;
    return await getIdToken(auth.currentUser, true);
  }

  return { user, loading, idToken };
}
