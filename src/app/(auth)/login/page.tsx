"use client";

import * as React from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { auth } from "@/services/firebase";
import { GoogleAuthProvider, signInWithPopup, getIdToken } from "firebase/auth";

export default function LoginPage() {
  const [email, setEmail] = React.useState("");
  const [error, setError] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(false);
  const [gLoading, setGLoading] = React.useState(false);
  const router = useRouter();
  const sp = useSearchParams();
  const next = sp.get("next") || "/dashboard";

  async function handleContinue() {
    setError(null);
    if (!/^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$/.test(email)) {
      setError("Enter a valid email.");
      return;
    }
    setLoading(true);
    const res = await fetch("/api/auth/session", {
      method: "POST",
      headers: { "Content-Type":"application/json" },
      body: JSON.stringify({ email })
    });
    setLoading(false);
    if (res.ok) router.push(next);
    else {
      const j = await res.json().catch(()=>({}));
      setError(j?.error || "Sign-in failed");
    }
  }

  async function handleGoogle() {
    setError(null);
    setGLoading(true);
    try {
      const provider = new GoogleAuthProvider();
      const cred = await signInWithPopup(auth, provider);
      const idToken = await getIdToken(cred.user, true);
      const r = await fetch("/api/auth/firebase/login", {
        method: "POST",
        headers: { "Content-Type":"application/json" },
        body: JSON.stringify({ idToken })
      });
      if (!r.ok) {
        const j = await r.json().catch(()=>({}));
        throw new Error(j?.error || "Google sign-in failed");
      }
      router.push(next);
    } catch (e: any) {
      setError(e?.message || "Google sign-in failed");
    } finally {
      setGLoading(false);
    }
  }

  return (
    <div className="container max-w-sm mx-auto p-8">
      <h1 className="text-xl font-semibold mb-4">Sign in</h1>

      <button
        className="h-10 px-4 border rounded w-full mb-4 disabled:opacity-60"
        onClick={handleGoogle}
        disabled={gLoading}
      >{gLoading ? "Connecting Google..." : "Continue with Google"}</button>

      <div className="my-4 text-center text-xs text-neutral-500">or</div>

      <label className="text-sm font-medium">Email</label>
      <input className="border rounded w-full h-10 px-3 mb-3" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@example.com" />
      {error && <p className="text-sm text-red-600 mb-2">{error}</p>}
      <button
        className="h-10 px-4 bg-black text-white rounded disabled:opacity-60 w-full"
        disabled={loading}
        onClick={handleContinue}
      >{loading ? "Continuing..." : "Continue with Email"}</button>

      <p className="text-xs mt-4 text-neutral-600">
        By continuing you agree to the Terms and acknowledge the Privacy Policy.
      </p>
    </div>
  );
}
