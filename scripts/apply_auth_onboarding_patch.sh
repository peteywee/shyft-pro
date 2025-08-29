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

# --- sanity: are we at repo root?
if [[ ! -f "package.json" ]]; then
  echo "ERROR: package.json not found. Run this from your project root."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

# helper: write a file with backup
write_file () {
  local path="$1"
  local content="$2"

  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"

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

# -----------------------------
# 1) src/lib/onboarding/state.ts
# -----------------------------
STATE_TS_CONTENT='// src/lib/onboarding/state.ts
import crypto from "node:crypto";

export type CompletionState = {
  complete: boolean;
  nextStep?: string;
  etag: string;
  updatedAt: number;
};

// In-memory cache (replace with Redis for production)
const memoryKV = new Map<string, CompletionState>();

export function cacheKey(userId: string, orgId: string) {
  return `onb:${orgId || "-"}:${userId || "-"}`;
}

export function computeEtag(snapshot: unknown): string {
  const json = JSON.stringify(snapshot || {});
  return crypto.createHash("sha1").update(json).digest("hex");
}

export function evaluateCompletion(snapshot: any): CompletionState {
  // Minimal, opinionated rules – adjust as your schema evolves.
  // Required gates for first-time flow:
  // 1) user.verified
  // 2) membership.choice in {"create","join"}
  // 3) if join -> membership.orgId present
  // 4) i9.section1.completed === true
  // 5) w4.submitted === true
  // 6) banking.added === true
  const okUser = !!snapshot?.user?.verified;
  const choice = snapshot?.membership?.choice;
  const okChoice = choice === "create" || choice === "join";
  const okOrg = choice === "create" ? true : !!snapshot?.membership?.orgId;
  const okI9 = !!snapshot?.i9?.section1?.completed;
  const okW4 = !!snapshot?.w4?.submitted;
  const okBank = !!snapshot?.banking?.added;

  const complete = Boolean(okUser && okChoice && okOrg && okI9 && okW4 && okBank);

  // Decide next step if not complete
  let nextStep: string | undefined;
  if (!okUser) nextStep = "verify-contact";
  else if (!okChoice) nextStep = "org-choice";
  else if (!okOrg) nextStep = "join-organization";
  else if (!okI9) nextStep = "i9-section1";
  else if (!okW4) nextStep = "w4";
  else if (!okBank) nextStep = "banking";

  return {
    complete,
    nextStep,
    etag: computeEtag(snapshot),
    updatedAt: Date.now()
  };
}

export function getCachedState(userId: string, orgId: string): CompletionState | undefined {
  return memoryKV.get(cacheKey(userId, orgId));
}

export function setCachedState(userId: string, orgId: string, state: CompletionState) {
  memoryKV.set(cacheKey(userId, orgId), { ...state, updatedAt: Date.now() });
}
'
write_file "src/lib/onboarding/state.ts" "$STATE_TS_CONTENT"

# -------------------------
# 2) src/lib/allowlist.ts
# -------------------------
ALLOWLIST_TS_CONTENT='// src/lib/allowlist.ts
export const ALLOWLIST = new Set<string>([
  "topshelfservicepros.com",
  "topshelfservicepros.net",
  "peteywee@outlook.com",
  "peteywee@gmail.com"
]);

export function isAllowed(email: string): boolean {
  const lower = email.toLowerCase().trim();
  if (ALLOWLIST.has(lower)) return true;
  const at = lower.lastIndexOf("@");
  if (at > 0) {
    const domain = lower.slice(at + 1);
    return ALLOWLIST.has(domain);
  }
  return false;
}
'
write_file "src/lib/allowlist.ts" "$ALLOWLIST_TS_CONTENT"

# ---------------------------------------------------
# 3) src/app/api/auth/session/route.ts  (overwrite)
# ---------------------------------------------------
SESSION_ROUTE_TS_CONTENT='import { NextRequest, NextResponse } from "next/server";
import crypto from "node:crypto";
import { db } from "@/lib/db-mock";
import { isAllowed } from "@/lib/allowlist";

/**
 * DEV-ONLY session creation
 */
export async function POST(req: NextRequest) {
  const { email, newAccount } = await req.json();
  if (!email) return NextResponse.json({ error: "email required" }, { status: 400 });
  if (!isAllowed(email)) return NextResponse.json({ error: "not allowed" }, { status: 403 });

  const userId = crypto.createHash("sha256").update(String(email)).digest("hex").slice(0, 16);
  const sid = crypto.randomBytes(12).toString("hex");

  db.putSession(sid, { userId });

  // Seed minimal onboarding snapshot baseline for this user
  db.setOnboarding("-", userId, {
    user: { emailOrPhone: email, authMethod: "password", verified: true, role: "staff" },
    membership: { choice: newAccount ? null : "join", orgId: "-", role: "staff" }
  });

  const res = NextResponse.json({ ok: true, userId });
  res.cookies.set("sid", {
    value: sid,
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 14, // 14 days
    secure: true
  } as any);
  return res;
}
'
write_file "src/app/api/auth/session/route.ts" "$SESSION_ROUTE_TS_CONTENT"

# ------------------------------------------------
# 4) src/app/api/auth/me/route.ts  (new endpoint)
# ------------------------------------------------
ME_ROUTE_TS_CONTENT='import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db-mock";

function getSid(req: NextRequest) { return req.cookies.get("sid")?.value || ""; }

export async function GET(req: NextRequest) {
  const sid = getSid(req);
  const sess = db.getSession(sid);
  if (!sess) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const snapshot = db.getOnboarding("-", sess.userId) || {};
  return NextResponse.json({ userId: sess.userId, snapshot });
}
'
write_file "src/app/api/auth/me/route.ts" "$ME_ROUTE_TS_CONTENT"

# -----------------
# 5) middleware.ts
# -----------------
MIDDLEWARE_TS_CONTENT='import { NextRequest, NextResponse } from "next/server";

const PUBLIC_PATHS = new Set<string>([
  "/",
  "/login",
  "/signup",
  "/api/auth/session"
]);

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  if (PUBLIC_PATHS.has(pathname) || pathname.startsWith("/_next") || pathname.startsWith("/assets")) {
    return NextResponse.next();
  }
  const sid = req.cookies.get("sid")?.value;
  if (!sid) {
    const url = req.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", pathname);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!api/health).*)"]
};
'
write_file "middleware.ts" "$MIDDLEWARE_TS_CONTENT"

# ----------------------------------------------
# 6) src/app/(auth)/login/page.tsx (overwrite)
# ----------------------------------------------
LOGIN_TSX_CONTENT='"use client";

import * as React from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginPage() {
  const [email, setEmail] = React.useState("");
  const [error, setError] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(false);
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

  return (
    <div className="container max-w-sm mx-auto p-8">
      <h1 className="text-xl font-semibold mb-4">Sign in</h1>
      <label className="text-sm font-medium">Email</label>
      <input className="border rounded w-full h-10 px-3 mb-3" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@example.com" />
      {error && <p className="text-sm text-red-600 mb-2">{error}</p>}
      <button
        className="h-10 px-4 bg-black text-white rounded disabled:opacity-60"
        disabled={loading}
        onClick={handleContinue}
      >{loading ? "Continuing..." : "Continue"}</button>
      <p className="text-sm mt-4">
        New here? <a className="underline" href="/signup">Create account</a>
      </p>
    </div>
  );
}
'
write_file "src/app/(auth)/login/page.tsx" "$LOGIN_TSX_CONTENT"

# -----------------------------------------------
# 7) src/app/(auth)/signup/page.tsx (overwrite)
# -----------------------------------------------
SIGNUP_TSX_CONTENT='"use client";

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
'
write_file "src/app/(auth)/signup/page.tsx" "$SIGNUP_TSX_CONTENT"

# --------------------------
# 8) README.md (append note)
# --------------------------
APPENDIX='

## Auth & Onboarding (dev)
- `/api/auth/session` issues a dev-only `sid` cookie (httpOnly, 14d). An allowlist is enforced via `src/lib/allowlist.ts`.
- `middleware.ts` protects non-public routes and redirects to `/login` when `sid` is absent.
- Onboarding completion rules live in `src/lib/onboarding/state.ts`. Replace in-memory cache with Redis and snapshots with Firestore in production.
- Client Firebase (if used) remains in `src/services/firebase.ts`. For SSR checks, prefer the `sid` dev cookie while wiring real auth later.
'
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[DRY] Would append to README.md"
else
  if [[ -f "README.md" ]]; then
    cp -p README.md "${BACKUP_DIR}/README.md"
    printf "%s" "$APPENDIX" >> README.md
    echo "Appended to README.md"
  else
    printf "# Project\n%s" "$APPENDIX" > README.md
    echo "Created README.md"
  fi
  FILES_CHANGED=$((FILES_CHANGED+1))
fi

echo
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ">>> DRY RUN complete. Files that would change: $FILES_CHANGED"
else
  echo "Patch applied. Files changed: $FILES_CHANGED"
  echo "Backups saved under: $BACKUP_DIR"
fi
