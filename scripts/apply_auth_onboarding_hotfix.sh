#!/usr/bin/env bash
set -euo pipefail

TS=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR=".patch_backups/${TS}"
mkdir -p "$BACKUP_DIR"

write_file () {
  local path="$1" content="$2"
  mkdir -p "$(dirname "$path")"
  if [[ -f "$path" ]]; then
    mkdir -p "${BACKUP_DIR}/$(dirname "$path")"
    cp -p "$path" "${BACKUP_DIR}/${path}"
    echo "Backup -> ${BACKUP_DIR}/${path}"
  fi
  printf "%s" "$content" > "$path"
  echo "Wrote: $path"
}

# 1) Shim: @/lib/firebase-admin  -> re-export our Admin SDK + provide db proxy
LIB_FIREBASE_ADMIN_TS='// src/lib/firebase-admin.ts
// Shim adapter so legacy imports keep working.
import { adminAuth as _adminAuth } from "@/server/firebaseAdmin";
import * as dbMock from "@/lib/db-mock";

// Export the adminAuth getter
export const adminAuth = _adminAuth;

// Some parts of the app imported { db } from "@/lib/firebase-admin"
// Re-export db-mock to preserve those call sites.
export const db = dbMock;
'
write_file "src/lib/firebase-admin.ts" "$LIB_FIREBASE_ADMIN_TS"

# 2) Shim: @/lib/firebase-client  -> re-export our client Firebase + providers
LIB_FIREBASE_CLIENT_TS='// src/lib/firebase-client.ts
// Shim adapter so legacy imports keep working.
import { auth } from "@/services/firebase";
import { GoogleAuthProvider } from "firebase/auth";

export { auth };
export const googleProvider = new GoogleAuthProvider();
'
write_file "src/lib/firebase-client.ts" "$LIB_FIREBASE_CLIENT_TS"

# 3) Unify /api/session: GET (me+state), POST (login via idToken or dev email), DELETE (logout)
API_SESSION_ROUTE_TS='import { NextRequest, NextResponse } from "next/server";
import { adminAuth } from "@/lib/firebase-admin";
import { db } from "@/lib/firebase-admin";
import { isAllowed } from "@/lib/allowlist";
import crypto from "node:crypto";
import { evaluateCompletion } from "@/lib/onboarding/state";

function sidFrom(req: NextRequest) { return req.cookies.get("sid")?.value || ""; }

export async function GET(req: NextRequest) {
  const sid = sidFrom(req);
  if (!sid) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const snapshot = db.getOnboarding("-", sid) || {};
  const state = evaluateCompletion(snapshot);
  return NextResponse.json({ userId: sid, snapshot, state });
}

/**
 * POST login:
 *  - If body has { idToken }, verify Firebase ID token -> set sid=uid (real Google sign-in)
 *  - Else if body has { email }, dev allowlist email flow -> sid=random (legacy/dev)
 */
export async function POST(req: NextRequest) {
  const { idToken, email, newAccount } = await req.json();

  // Prefer Firebase ID token when supplied
  if (idToken) {
    const decoded = await adminAuth().verifyIdToken(idToken, true);
    const uid = decoded.uid;

    // Seed minimal snapshot if missing
    const existing = db.getOnboarding("-", uid);
    if (!existing) {
      db.setOnboarding("-", uid, {
        user: { emailOrPhone: decoded.email || "", authMethod: "firebase", verified: !!decoded.email_verified, role: "staff" },
        membership: { choice: newAccount ? null : "join", orgId: "-", role: "staff" }
      });
    }

    const res = NextResponse.json({ ok: true, userId: uid, method: "firebase" });
    res.cookies.set("sid", { value: uid, httpOnly: true, sameSite: "lax", path: "/", maxAge: 60*60*24*14, secure: true } as any);
    return res;
  }

  // Fallback: dev email flow with allowlist
  if (email) {
    if (!isAllowed(email)) {
      return NextResponse.json({ error: "not allowed" }, { status: 403 });
    }
    const userId = crypto.createHash("sha256").update(String(email)).digest("hex").slice(0, 16);
    const sid = crypto.randomBytes(12).toString("hex");

    db.putSession(sid, { userId });
    db.setOnboarding("-", userId, {
      user: { emailOrPhone: email, authMethod: "password", verified: true, role: "staff" },
      membership: { choice: newAccount ? null : "join", orgId: "-", role: "staff" }
    });

    const res = NextResponse.json({ ok: true, userId, method: "dev-email" });
    res.cookies.set("sid", { value: sid, httpOnly: true, sameSite: "lax", path: "/", maxAge: 60*60*24*14, secure: true } as any);
    return res;
  }

  return NextResponse.json({ error: "idToken or email required" }, { status: 400 });
}

export async function DELETE() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set("sid", { value: "", path: "/", maxAge: 0 } as any);
  return res;
}
'
write_file "src/app/api/session/route.ts" "$API_SESSION_ROUTE_TS"

# 4) Middleware: make sure /api/session is public for POST login and GET is gated by cookie anyway
if [[ -f "middleware.ts" ]]; then
  cp -p middleware.ts "${BACKUP_DIR}/middleware.ts"
  sed -E 's|(const PUBLIC_PATHS = new Set<string>\(\[)|\1\n  "/api/session",|;' middleware.ts > middleware.ts.tmp
  mv middleware.ts.tmp middleware.ts
  echo "Patched middleware.ts to allow /api/session"
fi

echo
echo "Hotfix applied. Backups in ${BACKUP_DIR}"
echo "If you see Firebase Admin errors, ensure env vars are set:"
echo "  FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY"
