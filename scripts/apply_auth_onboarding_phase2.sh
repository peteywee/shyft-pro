#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
TS=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR=".patch_backups/${TS}"
FILES_CHANGED=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  echo ">>> DRY RUN: no files will be written."
fi

if [[ ! -f "package.json" ]]; then
  echo "ERROR: package.json not found. Run from repo root."
  exit 1
fi

mkdir -p "$BACKUP_DIR"
write_file () {
  local path="$1" content="$2"
  mkdir -p "$(dirname "$path")"
  if [[ -f "$path" ]]; then
    mkdir -p "${BACKUP_DIR}/$(dirname "$path")"
    cp -p "$path" "${BACKUP_DIR}/${path}"
    echo "Backup -> ${BACKUP_DIR}/${path}"
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY] Would write: $path"
  else
    printf "%s" "$content" > "$path"
    echo "Wrote: $path"
  fi
  FILES_CHANGED=$((FILES_CHANGED+1))
}

# 0) Ensure deps (documented; we do not install here)
# npm i firebase firebase-admin --save

# 1) Server Firebase Admin init (env-driven)
FIREBASE_ADMIN_TS='// src/server/firebaseAdmin.ts
import { cert, getApps, initializeApp, App } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

let app: App | null = null;

export function getAdminApp(): App {
  if (getApps().length) return getApps()[0]!;
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;
  if (privateKey && privateKey.startsWith("-----BEGIN")) {
    // ok
  } else if (privateKey) {
    // handle escaped newlines from env
    privateKey = privateKey.replace(/\\n/g, "\n");
  }

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Missing Firebase Admin env: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY");
  }

  app = initializeApp({
    credential: cert({ projectId, clientEmail, privateKey })
  });
  return app!;
}

export const adminAuth = () => getAuth(getAdminApp());
'
write_file "src/server/firebaseAdmin.ts" "$FIREBASE_ADMIN_TS"

# 2) API: Firebase login (verify ID token -> set sid)
FIREBASE_LOGIN_ROUTE='import { NextRequest, NextResponse } from "next/server";
import { adminAuth } from "@/server/firebaseAdmin";
import { db } from "@/lib/db-mock";

export async function POST(req: NextRequest) {
  const { idToken } = await req.json();
  if (!idToken) return NextResponse.json({ error: "idToken required" }, { status: 400 });

  const decoded = await adminAuth().verifyIdToken(idToken, true);
  const uid = decoded.uid;

  // Persist a minimal onboarding snapshot if none exists
  const existing = db.getOnboarding("-", uid);
  if (!existing) {
    db.setOnboarding("-", uid, {
      user: { emailOrPhone: decoded.email || "", authMethod: "firebase", verified: !!decoded.email_verified, role: "staff" },
      membership: { choice: null, orgId: "-", role: "staff" }
    });
  }

  const res = NextResponse.json({ ok: true, uid });
  res.cookies.set("sid", {
    value: uid,               // map sid to uid for simplicity
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 14,
    secure: true
  } as any);
  return res;
}
'
write_file "src/app/api/auth/firebase/login/route.ts" "$FIREBASE_LOGIN_ROUTE"

# 3) API: logout (clear cookie)
LOGOUT_ROUTE='import { NextResponse } from "next/server";

export async function POST() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set("sid", { value: "", path: "/", maxAge: 0 } as any);
  return res;
}
'
write_file "src/app/api/auth/logout/route.ts" "$LOGOUT_ROUTE"

# 4) Enhance /api/auth/me: include nextStep from evaluator
AUTH_ME_ROUTE='import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db-mock";
import { evaluateCompletion } from "@/lib/onboarding/state";

function getSid(req: NextRequest) { return req.cookies.get("sid")?.value || ""; }

export async function GET(req: NextRequest) {
  const sid = getSid(req);
  const sess = sid ? { userId: sid } : null; // sid is uid for Firebase or a random session for dev
  if (!sess) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const snapshot = db.getOnboarding("-", sess.userId) || {};
  const state = evaluateCompletion(snapshot);
  return NextResponse.json({ userId: sess.userId, snapshot, state });
}
'
write_file "src/app/api/auth/me/route.ts" "$AUTH_ME_ROUTE"

# 5) Client: augment login page with Google button (Firebase Web)
LOGIN_PAGE_TSX='"use client";

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
'
write_file "src/app/(auth)/login/page.tsx" "$LOGIN_PAGE_TSX"

# 6) README: env and usage notes
README_APPEND='

## Firebase Auth (Google) – server verification
Set these env vars in your runtime for Firebase Admin:
- FIREBASE_PROJECT_ID
- FIREBASE_CLIENT_EMAIL
- FIREBASE_PRIVATE_KEY  (escape newlines or provide as multiline secret)

Client uses Firebase Web SDK; on Google popup success we POST the ID token to `/api/auth/firebase/login`,
which verifies the token and sets the httpOnly `sid` cookie (mapped to uid).

Logout: ` + "`POST /api/auth/logout`" + ` clears the cookie.

Onboarding flow can use ` + "`GET /api/auth/me`" + ` to retrieve `{ state.nextStep }` from `evaluateCompletion()`
and redirect users to the next required step.
'
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[DRY] Would append to README.md"
else
  if [[ -f "README.md" ]]; then
    cp -p README.md "${BACKUP_DIR}/README.md"
    printf "%s" "$README_APPEND" >> README.md
    echo "Appended to README.md"
  else
    printf "# Project\n%s" "$README_APPEND" > README.md
    echo "Created README.md"
  fi
  FILES_CHANGED=$((FILES_CHANGED+1))
fi

echo
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ">>> DRY RUN complete. Files that would change: $FILES_CHANGED"
else
  echo "Phase-2 patch applied. Files changed: $FILES_CHANGED"
  echo "Backups saved under: $BACKUP_DIR"
  echo
  echo "Next:"
  echo "1) npm i firebase firebase-admin"
  echo "2) Set FIREBASE_* envs (Admin) in your local/dev environment."
  echo "3) Ensure your Firebase Web config is present in src/services/firebase.ts (VITE_ vars) and Google provider enabled in Firebase console."
fi
