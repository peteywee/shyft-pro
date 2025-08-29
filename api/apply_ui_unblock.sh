#!/usr/bin/env bash
set -euo pipefail
TS=$(date +"%Y%m%d_%H%M%S"); BK=".patch_backups/$TS"; mkdir -p "$BK"
b(){ [[ -f "$1" ]] && mkdir -p "$BK/$(dirname "$1")" && cp -p "$1" "$BK/$1" && echo "Backup -> $BK/$1" || true; }
w(){ mkdir -p "$(dirname "$1")"; b "$1"; cat > "$1"; echo "Wrote: $1"; }

# 1) Health endpoint for Next.js app
w app/api/health/route.ts <<'TS'
import { NextResponse } from "next/server";
export async function GET() { return NextResponse.json({ ok: true, service: "next-app" }); }
TS

# 2) Minimal home page that never redirects
w app/page.tsx <<'TSX'
export default function Home() {
  return (
    <main className="p-8">
      <h1 className="text-2xl font-semibold">Ryne • Home</h1>
      <p className="mt-2 text-sm text-neutral-600">
        This page always renders. <a className="underline" href="/login">Sign in</a>.
      </p>
      <ul className="mt-4 list-disc pl-6 text-sm">
        <li><a className="underline" href="/api/health">/api/health</a> (Next health)</li>
        <li><a className="underline" href="/api/debug/cookies">/api/debug/cookies</a> (cookie debug)</li>
      </ul>
    </main>
  );
}
TSX

# 3) Minimal onboarding page (reads /api/session state, shows next step, complete button)
w app/onboarding/page.tsx <<'TSX'
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
TSX

# 4) API endpoint to mark onboarding complete in db-mock and set onb=1 cookie
w app/api/onboarding/complete/route.ts <<'TS'
import { NextRequest, NextResponse } from "next/server";
import { db } from "../../lib/firebase-admin";

function sid(req: NextRequest) { return req.cookies.get("sid")?.value || ""; }

export async function POST(req: NextRequest) {
  const s = sid(req);
  if (!s) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  // Merge minimal flags into existing snapshot
  const snap = db.getOnboarding("-", s) || {};
  const nextSnap = {
    ...snap,
    user: { ...(snap.user || {}), verified: true },
    membership: { ...(snap.membership || {}), choice: "join", orgId: "-" },
    i9: { ...(snap.i9 || {}), section1: { completed: true } },
    w4: { submitted: true },
    banking: { added: true }
  };
  db.setOnboarding("-", s, nextSnap);

  const res = NextResponse.json({ ok: true });
  res.cookies.set("onb", "1", {
    path: "/",
    maxAge: 3600,
    secure: process.env.NODE_ENV === "production"
  } as any);
  return res;
}
TS

# 5) Ensure middleware whitelists /api/health and keeps /onboarding open once signed-in
if [[ -f "middleware.ts" ]]; then
  b middleware.ts
  awk '
    BEGIN { added=0 }
    /const PUBLIC_PATHS = new Set<string>\(\[/ {
      print; print "  \"/api/health\",";
      added=1; next
    }
    { print }
    END { if (!added) { } }
  ' middleware.ts > middleware.ts.new
  mv middleware.ts.new middleware.ts
  echo "Patched middleware.ts to allow /api/health"
fi

echo "Done. Backups in $BK"
