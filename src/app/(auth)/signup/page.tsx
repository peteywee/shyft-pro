"use client";

import * as React from "react";
import { useRouter } from "next/navigation";

export default function SignupPage() {
  const [email, setEmail] = React.useState("");
  const [error, setError] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(false);
  const router = useRouter();

  async function handleCreate() {
    setError(null);
    if (!/^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$/.test(email)) {
      setError("Enter a valid email.");
      return;
    }
    setLoading(true);
    const res = await fetch("/api/auth/session", {
      method: "POST",
      headers: { "Content-Type":"application/json" },
      body: JSON.stringify({ email, newAccount: true })
    });
    setLoading(false);
    if (res.ok) router.replace("/onboarding");
    else {
      const j = await res.json().catch(()=>({}));
      setError(j?.error || "Sign-up failed");
    }
  }

  return (
    <div className="container max-w-sm mx-auto p-8">
      <h1 className="text-xl font-semibold mb-4">Create account</h1>
      <label className="text-sm font-medium">Work email</label>
      <input className="border rounded w-full h-10 px-3 mb-3" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@company.com" />
      {error && <p className="text-sm text-red-600 mb-2">{error}</p>}
      <button
        className="h-10 px-4 bg-black text-white rounded disabled:opacity-60"
        disabled={loading}
        onClick={handleCreate}
      >{loading ? "Creating..." : "Create account"}</button>
      <p className="text-sm mt-4">
        Already have an account? <a className="underline" href="/login">Sign in</a>
      </p>
    </div>
  );
}
