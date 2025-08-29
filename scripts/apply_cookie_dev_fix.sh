#!/usr/bin/env bash
set -euo pipefail
TS=$(date +"%Y%m%d_%H%M%S"); BK=".patch_backups/$TS"; mkdir -p "$BK"

b(){ [[ -f "$1" ]] && mkdir -p "$BK/$(dirname "$1")" && cp -p "$1" "$BK/$1" && echo "Backup -> $BK/$1" || true; }

# 1) Normalize cookie 'secure' flags to prod-only in /api/session
if [[ -f "app/api/session/route.ts" ]]; then
  b app/api/session/route.ts
  # sid (set in POST for firebase and dev-email)
  sed -E -i '
    s/(res\.cookies\.set\("sid",[[:space:]]*\{[^}]*secure:)[[:space:]]*true/\1 process.env.NODE_ENV === "production"/g;
  ' app/api/session/route.ts

  # onb=1 (set when complete in GET)
  sed -E -i '
    s/(r\.cookies\.set\("onb",[[:space:]]*"1",[[:space:]]*\{[^}]*)(\})/\1 , secure: process.env.NODE_ENV === "production" \2/g;
  ' app/api/session/route.ts

  # logout clears cookie — keep it not secure so it clears in dev too
  echo "Patched app/api/session/route.ts"
fi

# 2) If you still have older endpoints that set 'sid', patch them as well
for f in \
  src/app/api/auth/session/route.ts \
  src/app/api/auth/firebase/login/route.ts \
  src/app/api/auth/logout/route.ts
do
  [[ -f "$f" ]] || continue
  b "$f"
  sed -E -i '
    s/(res\.cookies\.set\("sid",[[:space:]]*\{[^}]*secure:)[[:space:]]*true/\1 process.env.NODE_ENV === "production"/g;
  ' "$f"
  echo "Patched $f"
done

# 3) Add a quick cookie debug endpoint: GET /api/debug/cookies -> returns cookie map
cat > app/api/debug/cookies/route.ts <<'TS'
import { NextRequest, NextResponse } from "next/server";

export async function GET(req: NextRequest) {
  const ck = Object.fromEntries((req.cookies.getAll() || []).map(c => [c.name, c.value]));
  return NextResponse.json({ cookies: ck });
}
TS
echo "Wrote app/api/debug/cookies/route.ts"

echo
echo "Done. Backups in $BK"
echo "Restart: npm run dev"
