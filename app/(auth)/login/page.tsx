"use client";

import { useEffect, useState } from "react";
import { auth, googleProvider } from "@/lib/firebase-client";
import {
  signInWithPopup,
  signInWithEmailAndPassword,
  onAuthStateChanged,
} from "firebase/auth";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [pass, setPass] = useState("");
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const qp = useSearchParams();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;

      // 1) Exchange ID token for an httpOnly session cookie
      const idToken = await user.getIdToken();
      await fetch("/api/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ idToken }),
      });

      // 2) Ask server if onboarding is complete, then route
      const r = await fetch("/api/session", { cache: "no-store" });
      const { onboardingComplete } = await r.json();
      if (onboardingComplete) router.replace(qp.get("next") || "/dashboard");
      else router.replace("/onboarding");
    });
    return () => unsub();
  }, [router, qp]);

  const loginGoogle = async () => {
    try {
      setError(null);
      await signInWithPopup(auth, googleProvider);
    } catch (e: any) {
      setError(e.message || "Google sign-in failed.");
    }
  };

  const loginEmail = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setError(null);
      await signInWithEmailAndPassword(auth, email, pass);
    } catch (err: any) {
      setError(err.message || "Email sign-in failed.");
    }
  };

  return (
    <main className="max-w-md mx-auto p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Sign in</h1>

      <button onClick={loginGoogle} className="w-full rounded-xl border px-4 py-3">
        Continue with Google
      </button>

      <div className="text-center text-sm opacity-60">or</div>

      <form onSubmit={loginEmail} className="space-y-3">
        <input
          type="email"
          placeholder="Email"
          className="w-full border rounded-xl px-3 py-2"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          autoComplete="email"
        />
        <input
          type="password"
          placeholder="Password"
          className="w-full border rounded-xl px-3 py-2"
          value={pass}
          onChange={(e) => setPass(e.target.value)}
          required
          autoComplete="current-password"
        />
        <button className="w-full rounded-xl bg-black text-white px-4 py-3">
          Sign in with Email
        </button>
      </form>

      {error && <p className="text-red-600 text-sm">{error}</p>}
    </main>
  );
}
