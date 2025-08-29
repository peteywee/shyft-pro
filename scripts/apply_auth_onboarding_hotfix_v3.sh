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

# 1) Bridge files so imports like "../../lib/firebase-admin" (from app/*) resolve.

# app/lib/firebase-admin.ts  -> re-export src/lib/firebase-admin
write "app/lib/firebase-admin.ts" $'// Bridge to src/lib/firebase-admin\nexport * from "../../src/lib/firebase-admin";\nexport { default as default } from "../../src/lib/firebase-admin";\n'

# app/lib/allowlist.ts -> src/lib/allowlist
write "app/lib/allowlist.ts" $'// Bridge to src/lib/allowlist\nexport * from "../../src/lib/allowlist";\nexport { default as default } from "../../src/lib/allowlist";\n'

# app/lib/onboarding/state.ts -> src/lib/onboarding/state
write "app/lib/onboarding/state.ts" $'// Bridge to src/lib/onboarding/state\nexport * from "../../../src/lib/onboarding/state";\nexport { default as default } from "../../../src/lib/onboarding/state";\n'

# 2) Ensure db-mock exists (dev only). If you already have it in src/lib/db-mock.ts, this is skipped.
if [[ ! -f "src/lib/db-mock.ts" ]]; then
  write "src/lib/db-mock.ts" $'// Minimal in-memory db for dev\n\
type Session = { userId: string };\n\
type Snapshot = Record<string, any>;\n\
const sessions = new Map<string, Session>();\n\
const onboarding = new Map<string, Map<string, Snapshot>>();\n\
const orgMap = (orgId:string)=>{ const k=orgId||"-"; if(!onboarding.has(k)) onboarding.set(k,new Map()); return onboarding.get(k)!; };\n\
export function putSession(sid:string, s:Session){ sessions.set(sid,s); }\n\
export function getSession(sid:string){ return sessions.get(sid) || null; }\n\
export function setOnboarding(orgId:string, userId:string, snap:Snapshot){ orgMap(orgId).set(userId,snap); }\n\
export function getOnboarding(orgId:string, userId:string){ return orgMap(orgId).get(userId) || null; }\n\
export const db = { putSession, getSession, setOnboarding, getOnboarding };\n\
export default db;\n'
fi

# 3) If your app/api/session/route.ts still uses alias paths, normalize to app-local bridges.
if [[ -f "app/api/session/route.ts" ]]; then
  backup "app/api/session/route.ts"
  sed -E \
    -e 's#@/lib/firebase-admin#../../lib/firebase-admin#g' \
    -e 's#@/lib/allowlist#../../lib/allowlist#g' \
    -e 's#@/lib/onboarding/state#../../lib/onboarding/state#g' \
    -i "app/api/session/route.ts"
  echo "Patched imports in app/api/session/route.ts -> app/lib bridges"
fi

echo
echo "Bridges in place. Next: install CSS deps if Tailwind is configured."
