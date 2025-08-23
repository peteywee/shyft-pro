#!/usr/bin/env bash
set -euo pipefail

# Fail if tools are missing
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1"; exit 1; }; }

echo "===> Running secret scans (working tree + history)..."

# Prefer gitleaks if present, otherwise use Docker image
if command -v gitleaks >/dev/null 2>&1; then
  echo "--- gitleaks (working tree)"
  gitleaks protect --verbose --redact --config=.gitleaks.toml || true
  echo "--- gitleaks (full history)"
  gitleaks detect --verbose --redact --config=.gitleaks.toml || true
elif command -v docker >/dev/null 2>&1; then
  echo "--- gitleaks via docker (working tree)"
  docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest \
    protect -v --redact -c /repo/.gitleaks.toml -s /repo || true
  echo "--- gitleaks via docker (full history)"
  docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest \
    detect -v --redact -c /repo/.gitleaks.toml -s /repo || true
else
  echo "WARN: gitleaks not found (binary or docker). Skipping."
fi

# TruffleHog (if installed)
if command -v trufflehog >/dev/null 2>&1; then
  echo "--- trufflehog (git history high-entropy + regex)"
  trufflehog git file://$PWD --no-update --since-commit $(git rev-list --max-parents=0 HEAD) || true
fi

# Fast ripgrep sweep for obvious patterns
if command -v rg >/dev/null 2>&1; then
  echo "--- ripgrep high-signal patterns"
  rg -n --hidden --glob '!.git' --glob '!node_modules' --glob '!.next' \
    -e '(?i)(api[_-]?key|secret|token|password|passwd|authorization)\s*[:=]\s*[\"\x27]?[A-Za-z0-9_\-]{12,}' \
    -e 'sk-[A-Za-z0-9]{20,}' \
    -e 'AIza[0-9A-Za-z\-_]{35}' \
    -e '"type"\s*:\s*"service_account"' || true
fi

echo "===> Scans complete. Review any findings above."
