#!/usr/bin/env bash
set -euo pipefail

KEY_JSON="${1:-new-key.json}"
ENV_FILE="${2:-.env.local}"

if [[ ! -f "$KEY_JSON" ]]; then
  echo "ERROR: $KEY_JSON not found."
  exit 1
fi

B64="$(base64 -w 0 "$KEY_JSON" 2>/dev/null || base64 "$KEY_JSON" | tr -d '\n')"

# Remove existing then append
{ grep -v '^FIREBASE_SERVICE_ACCOUNT_B64=' "$ENV_FILE" 2>/dev/null || true; } > "${ENV_FILE}.tmp"
mv "${ENV_FILE}.tmp" "$ENV_FILE"
echo "FIREBASE_SERVICE_ACCOUNT_B64=$B64" >> "$ENV_FILE"

echo "Wrote FIREBASE_SERVICE_ACCOUNT_B64 to $ENV_FILE"
