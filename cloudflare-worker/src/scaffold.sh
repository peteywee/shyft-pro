#!/usr/bin/env bash
set -euo pipefail

# Root of your project (adjust if needed)
ROOT="$(pwd)"

# Array of file paths we want to scaffold
FILES=(
  "src/lib/firebase.ts"
  "src/app/(auth)/signup/page.tsx"
  "src/app/(auth)/login/page.tsx"
  "src/app/(auth)/organization-setup/page.tsx"
  "src/app/(app)/onboarding/page.tsx"
  "src/app/(app)/dashboard/page.tsx"
  "src/app/(app)/schedule-assistant/page.tsx"
  "src/app/(app)/schedule-assistant/actions.ts"
  "cloudflare-worker/wrangler.toml"
  "cloudflare-worker/src/index.ts"
  "cloudflare-worker/src/verifyAuth.ts"
  "public/manifest.json"
  "next.config.ts"
  "firestore.rules"
)

echo "Scaffolding project files..."

for f in "${FILES[@]}"; do
  dir="$ROOT/$(dirname "$f")"
  mkdir -p "$dir"
  touch -c "$ROOT/$f"
  echo "✔ ensured $f"
done

echo "Done. Empty files created where missing (existing left untouched)."
