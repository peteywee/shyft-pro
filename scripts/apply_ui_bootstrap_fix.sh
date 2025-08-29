#!/usr/bin/env bash
set -euo pipefail

TS=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR=".patch_backups/${TS}"
mkdir -p "$BACKUP_DIR"

b() { [[ -f "$1" ]] && mkdir -p "${BACKUP_DIR}/$(dirname "$1")" && cp -p "$1" "${BACKUP_DIR}/$1" && echo "Backup -> ${BACKUP_DIR}/$1" || true; }
w() { mkdir -p "$(dirname "$1")"; b "$1"; printf "%s" "$2" > "$1"; echo "Wrote: $1"; }

# 1) Next-safe Firebase client (no Vite-only envs at import time, lazy, no throw)
read -r -d '' FIREBASE_TS <<'TS'
// src/services/firebase.ts
import { initializeApp, type FirebaseApp } from "firebase/app";
import { getAuth, setPersistence, browserLocalPersistence, type Auth } from "firebase/auth";

// Resolve config from NEXT_PUBLIC_* first (Next.js), then VITE_* (compat), then window-injected (optional)
function resolveConfig() {
  const env = (typeof process !== "undefined" && process.env) ? process.env : {};
  const vite = (typeof import.meta !== "undefined" && (import.meta as any).env) ? (import.meta as any).env : {};
  const win: any = (typeof window !== "undefined") ? (window as any) : {};

  const cfg = {
    apiKey: env.NEXT_PUBLIC_FIREBASE_API_KEY || vite.VITE_FIREBASE_API_KEY || win.__FIREBASE_API_KEY__,
    authDomain: env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || vite.VITE_FIREBASE_AUTH_DOMAIN || win.__FIREBASE_AUTH_DOMAIN__,
    projectId: env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || vite.VITE_FIREBASE_PROJECT_ID || win.__FIREBASE_PROJECT_ID__,
    storageBucket: env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || vite.VITE_FIREBASE_STORAGE_BUCKET || win.__FIREBASE_STORAGE_BUCKET__,
    messagingSenderId: env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || vite.VITE_FIREBASE_MESSAGING_SENDER_ID || win.__FIREBASE_MESSAGING_SENDER_ID__,
    appId: env.NEXT_PUBLIC_FIREBASE_APP_ID || vite.VITE_FIREBASE_APP_ID || win.__FIREBASE_APP_ID__
  };

  // Require the minimum keys only when actually initializing in the browser
  return cfg;
}

let _app: FirebaseApp | null = null;
let _auth: Auth | null = null;

export function ensureFirebase(): { app: FirebaseApp; auth: Auth } {
  if (typeof window === "undefined") {
    // SSR: do not initialize; callers should guard usage.
    throw new Error("ensureFirebase() called server-side; guard with `typeof window !== 'undefined'`.");
  }
  if (_app && _auth) return { app: _app, auth: _auth };

  const cfg = resolveConfig();
  const required = ["apiKey", "authDomain", "projectId", "appId"] as const;
  const missing = required.filter(k => !(cfg as any)[k]);
  if (missing.length) {
    throw new Error("Firebase client config missing: " + missing.join(", "));
  }
  _app = initializeApp(cfg as any);
  _auth = getAuth(_app);
  setPersistence(_auth, browserLocalPersistence);
  return { app: _app, auth: _auth };
}

// Optional named export for shims expecting `auth`
export const auth: Auth | null = (typeof window !== "undefined") ? ensureFirebase().auth : null;
TS
w "src/services/firebase.ts" "$FIREBASE_TS"

# 2) Lazy-load Firebase on the login page: no client SDK until user clicks.
read -r -d '' LOGIN_TSX <<'TSX'
"use client";

import * as React from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginPage() {
  const [email, setEmail] = React.useState("");
  const [err, setErr] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(false);
  const [gLoading, setGLoading] = React.useState(false);
  const router = useRouter();
  const sp = useSearchParams();
  const next = sp.get("next") || "/dashboard";

  async function handleEmail() {
    setErr(null);
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      setErr("Enter a valid email.");
      return;
    }
    setLoading(true);
    try {
      const res = await fetch("/api/session", {
        method: "POST",
        headers: { "Content-Type":"application/json" },
        body: JSON.stringify({ email })
      });
      if (!res.ok) throw new Error((await res.json().catch(()=>({}))).error || "Email sign-in failed");
      router.push(next);
    } catch (e:any) {
      setErr(e?.message || "Email sign-in failed");
    } finally {
      setLoading(false);
    }
  }

  async function handleGoogle() {
    setErr(null);
    setGLoading(true);
    try {
      // Lazy import only on click
      const [{ ensureFirebase }, { GoogleAuthProvider, signInWithPopup, getIdToken }] = await Promise.all([
        import("@/services/firebase"),
        import("firebase/auth"),
      ]);
      const { auth } = ensureFirebase();
      const provider = new GoogleAuthProvider();
      const cred = await signInWithPopup(auth, provider);
      const idToken = await getIdToken(cred.user, true);
      const r = await fetch("/api/session", {
        method: "POST",
        headers: { "Content-Type":"application/json" },
        body: JSON.stringify({ idToken })
      });
      if (!r.ok) throw new Error((await r.json().catch(()=>({}))).error || "Google sign-in failed");
      router.push(next);
    } catch (e:any) {
      setErr(e?.message || "Google sign-in failed");
    } finally {
      setGLoading(false);
    }
  }

  return (
    <div className="container max-w-sm mx-auto p-8">
      <h1 className="text-xl font-semibold mb-4">Sign in</h1>

      <button className="h-10 px-4 border rounded w-full mb-4 disabled:opacity-60"
              onClick={handleGoogle} disabled={gLoading}>
        {gLoading ? "Connecting Google..." : "Continue with Google"}
      </button>

      <div className="my-4 text-center text-xs text-neutral-500">or</div>

      <label className="text-sm font-medium">Email</label>
      <input className="border rounded w-full h-10 px-3 mb-3"
             value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@example.com" />
      {err && <p className="text-sm text-red-600 mb-2">{err}</p>}
      <button className="h-10 px-4 bg-black text-white rounded disabled:opacity-60 w-full"
              disabled={loading} onClick={handleEmail}>
        {loading ? "Continuing..." : "Continue with Email"}
      </button>
    </div>
  );
}
TSX
w "app/(auth)/login/page.tsx" "$LOGIN_TSX"

# 3) Set 'onb=1' cookie when onboarding is complete; middleware can skip guard fetch.
if [[ -f "app/api/session/route.ts" ]]; then
  sed -E -i.bak \
    -e 's|(return NextResponse\.json\(\{ userId: sid, snapshot, state \}\);)|const r=NextResponse.json({ userId: sid, snapshot, state }); if (state?.complete) { r.cookies.set("onb","1",{path:"/",maxAge:3600}); } return r;|' \
    "app/api/session/route.ts"
  echo "Patched app/api/session/route.ts to set onb=1 when complete."
fi

# 4) Middleware: skip /api/auth/guard fetch if cookie onb=1 exists.
if [[ -f "middleware.ts" ]]; then
  b "middleware.ts"
  awk '
    /const PUBLIC_PATHS/ { print; print "const ONB_COOKIE = \"onb\";"; next }
    /const sid = req\.cookies\.get\("sid"\)\?\.value;/ { print; print "  const onb = req.cookies.get(ONB_COOKIE)?.value;"; next }
    /\/\/ Check completion via server guard/ {
      print "  // If we already have onb=1, skip guard fetch";
      print "  if (onb === \"1\") { return NextResponse.next(); }";
      print;
      next
    }
    { print }
  ' middleware.ts > middleware.ts.new
  mv middleware.ts.new middleware.ts
  echo "Patched middleware.ts to short-circuit when onb=1."
fi

echo
echo ">> Patch applied. Backups under ${BACKUP_DIR}"
echo "Next steps:"
echo "1) Ensure .env.local has NEXT_PUBLIC_FIREBASE_* keys (at least API key, auth domain, projectId, appId)."
echo "2) Restart dev server: npm run dev"
