#!/usr/bin/env bash
set -euo pipefail

TS=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR=".patch_backups/${TS}"
mkdir -p "$BACKUP_DIR"

backup() {
  local p="$1"
  [[ -f "$p" ]] || return 0
  mkdir -p "${BACKUP_DIR}/$(dirname "$p")"
  cp -p "$p" "${BACKUP_DIR}/${p}"
  echo "Backup -> ${BACKUP_DIR}/${p}"
}

write() {
  local p="$1" c="$2"
  mkdir -p "$(dirname "$p")"
  backup "$p"
  printf "%s" "$c" > "$p"
  echo "Wrote: $p"
}

# 1) Minimal in-memory db mock used by session + guard
DB_MOCK_TS='// src/lib/db-mock.ts
// Super-simple in-memory stores for dev only. Replace with Firestore later.

type Session = { userId: string };
type Snapshot = Record<string, any>;

const sessions = new Map<string, Session>();
// Keyed by orgId (we use "-" for single-tenant dev) then userId
const onboarding = new Map<string, Map<string, Snapshot>>();

function getOrg(orgId: string) {
  const k = orgId || "-";
  if (!onboarding.has(k)) onboarding.set(k, new Map());
  return onboarding.get(k)!;
}

export function putSession(sid: string, session: Session) {
  sessions.set(sid, session);
}
export function getSession(sid: string) {
  return sessions.get(sid) || null;
}

export function setOnboarding(orgId: string, userId: string, snapshot: Snapshot) {
  getOrg(orgId).set(userId, snapshot);
}
export function getOnboarding(orgId: string, userId: string): Snapshot | null {
  return getOrg(orgId).get(userId) || null;
}

export const db = { putSession, getSession, setOnboarding, getOnboarding };
export default db;
'
write "src/lib/db-mock.ts" "$DB_MOCK_TS"

# 2) Fix shim: firebase-admin re-exports adminAuth and db (from db-mock)
FIREBASE_ADMIN_TS='// src/lib/firebase-admin.ts
// Shim adapter so legacy imports keep working.
import { adminAuth as _adminAuth } from "../server/firebaseAdmin"; // relative import
import dbDefault, * as dbMock from "./db-mock";

// Export the adminAuth getter
export const adminAuth = _adminAuth;

// Some call sites use `db.method(...)`
export const db = dbMock as unknown as typeof dbDefault;
export default { adminAuth, db };
'
write "src/lib/firebase-admin.ts" "$FIREBASE_ADMIN_TS"

# 3) Fix shim: firebase-client imports client firebase relatively to avoid alias issues
FIREBASE_CLIENT_TS='// src/lib/firebase-client.ts
// Shim adapter so legacy imports keep working.
import { auth } from "../services/firebase";
import { GoogleAuthProvider } from "firebase/auth";

export { auth };
export const googleProvider = new GoogleAuthProvider();
export default { auth, googleProvider };
'
write "src/lib/firebase-client.ts" "$FIREBASE_CLIENT_TS"

# 4) Ensure app/globals.css exists (Next complains if missing)
if [[ ! -f "app/globals.css" ]]; then
  GLOBALS_CSS='/* Minimal global styles to satisfy Next import */
:root { --bg: #ffffff; --fg: #111111; }
html, body { height: 100%; background: var(--bg); color: var(--fg); }
* { box-sizing: border-box; }
'
  write "app/globals.css" "$GLOBALS_CSS"
fi

# 5) Nudge /api/session route to avoid alias issues internally (optional safety)
if [[ -f "app/api/session/route.ts" ]]; then
  backup "app/api/session/route.ts"
  sed -E \
    -e 's#@/lib/firebase-admin#../../lib/firebase-admin#g' \
    -e 's#@/lib/allowlist#../../lib/allowlist#g' \
    -e 's#@/lib/onboarding/state#../../lib/onboarding/state#g' \
    -i "app/api/session/route.ts"
  echo "Patched imports in app/api/session/route.ts -> relative paths"
fi

echo
echo "Hotfix v2 applied. Backups in ${BACKUP_DIR}"
echo "Now run:  npm run dev"
