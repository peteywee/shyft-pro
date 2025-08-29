"use client";

import * as React from "react";
import { useRouter } from "next/navigation";

type Me = {
  userId: string;
  state?: { complete: boolean; nextStep?: string | null };
};

export default function OnboardingPage() {
  const [me, setMe] = React.useState<Me | null>(null);
  const [err, setErr] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(false);
  const router = useRouter();

  React.useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const r = await fetch("/api/session", { cache: "no-store" });
        if (!r.ok) throw new Error(`session: ${r.status}`);
        const j = await r.json();
        if (!cancelled) setMe(j);
      } catch (e: any) {
        setErr(e?.message || "Failed to load session");
      }
    })();
    return () => { cancelled = true; };
  }, []);

  async function markComplete() {
    setLoading(true);
    setErr(null);
    try {
      const r = await fetch("/api/onboarding/complete", { method: "POST" });
      if (!r.ok) throw new Error("Failed to complete onboarding");
      router.push("/dashboard");
    } catch (e:any) {
      setErr(e?.message || "Failed to complete onboarding");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="p-8">
      <h1 className="text-2xl font-semibold">Onboarding</h1>
      {err && <p className="text-sm text-red-600 mt-2">{err}</p>}
      {!me && !err && <p className="mt-2 text-sm text-neutral-600">Loading…</p>}
      {me && (
        <div className="mt-4 text-sm">
          <p><b>User:</b> {me.userId}</p>
          {me.state?.complete ? (
            <>
              <p className="mt-2">Onboarding complete. You can proceed.</p>
              <a className="underline" href="/dashboard">Go to dashboard</a>
            </>
          ) : (
            <>
              <p className="mt-2">Next required step: <b>{me.state?.nextStep || "unspecified"}</b></p>
              <button
                className="mt-3 h-10 px-4 bg-black text-white rounded disabled:opacity-60"
                onClick={markComplete}
                disabled={loading}
              >
                {loading ? "Completing…" : "Mark onboarding complete (dev)"}
              </button>
            </>
          )}
        </div>
      )}
    </main>
  );
}
