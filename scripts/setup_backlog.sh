#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# 0) CONFIG
# ──────────────────────────────────────────────────────────────────────────────
REPO="ORG/REPO"                    # e.g., my-org/shyft-onboarding
BRANCH="chore/create-parsing-backlog"
MILESTONE="Production Release"
PRIORITY_LABEL="priority: high"

# TODO titles (exact strings)
ISSUE_TITLES=(
  "Document Parsing Pipeline: OCR → Classify → Extract → Apply (with human review)"
  "Direct Deposit: support multiple accounts with allocations"
  "Redacted Previews: mask SSN and bank numbers in all document previews"
  "Owner/Manager Review Inbox for I-9 S2 + low-confidence parses"
  "GenAI Adapter (optional): classification & field extraction via Vertex/GenKit"
  "Observability: metrics, tracing, alerts for onboarding & parsing"
  "Legal: retention policies & purge jobs for I-9/W-4/Direct Deposit"
)

# ──────────────────────────────────────────────────────────────────────────────
# 1) PREREQS
# ──────────────────────────────────────────────────────────────────────────────
if ! command -v gh >/dev/null 2>&1; then
  echo "⚠️  GitHub CLI (gh) not found. Install from https://cli.github.com/ and re-run."
  exit 1
fi

# Ensure gh is authenticated
if ! gh auth status -R "$REPO" >/dev/null 2>&1; then
  echo "🔐 Running gh auth login…"
  gh auth login
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2) BRANCH + FILES
# ──────────────────────────────────────────────────────────────────────────────
# Create/checkout branch
if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH"
fi

mkdir -p .github/ISSUE_TEMPLATE

# Issue template
cat > .github/ISSUE_TEMPLATE/feature.md <<'EOF'
---
name: Feature
about: Feature request or backlog item
title: "[Feature] "
labels: ["enhancement"]
assignees: []
---

## Summary
<!-- one-liner -->

## Problem / Why
<!-- what hurts or is missing -->

## Scope / Acceptance Criteria
- [ ] ...

## Tech Notes
- Areas: [frontend|backend|infra]
- Risks:
- Observability:

## Out of Scope
-
EOF

# Backlog overview
cat > ISSUE_BREAKDOWN.md <<'EOF'
# Shyft Onboarding — Parsing & Compliance Backlog

This file mirrors the issues created via gh CLI. Each item links to the issue once created.

1. Document Parsing Pipeline (OCR → Classify → Extract → Apply) — labels: enhancement, backend, parsing, PII
2. Multi-account Direct Deposit (allocations) — labels: enhancement, backend, payroll
3. Redacted Previews for PII docs — labels: security, frontend, backend, PII
4. Owner/Manager Review Inbox — labels: enhancement, frontend, backend
5. Optional GenAI/Vertex adapter — labels: enhancement, ml, parsing
6. Observability (metrics, tracing, alerts) — labels: observability, infra
7. Legal Retention & Purge Schedules — labels: compliance, security, backend
EOF

git add .github/ISSUE_TEMPLATE/feature.md ISSUE_BREAKDOWN.md
git commit -m "chore: add issue template and backlog breakdown" || true

# ──────────────────────────────────────────────────────────────────────────────
# 3) LABELS (ensure they exist; safe to re-run)
# ──────────────────────────────────────────────────────────────────────────────
ensure_label () {
  local name="$1" color="$2" desc="$3"
  gh label create "$name" -R "$REPO" -c "$color" -d "$desc" 2>/dev/null || true
}
ensure_label "enhancement"       "#1D76DB" "New feature or request"
ensure_label "backend"           "#5319E7" "Server-side work"
ensure_label "frontend"          "#0E8A16" "Client-side work"
ensure_label "parsing"           "#B60205" "OCR/Extraction/Classification"
ensure_label "PII"               "#FBCA04" "Sensitive data handling"
ensure_label "payroll"           "#0052CC" "Pay & deposits"
ensure_label "security"          "#D93F0B" "Security/privacy"
ensure_label "observability"     "#5319E7" "Metrics/Tracing/Alerts"
ensure_label "infra"             "#A2EEEF" "Infrastructure/ops"
ensure_label "compliance"        "#F9D0C4" "Regulatory/Retention"
ensure_label "ml"                "#C2E0C6" "Machine learning"
ensure_label "$PRIORITY_LABEL"   "#B60205" "High priority, must be completed before production release"

# ──────────────────────────────────────────────────────────────────────────────
# 4) MILESTONE (ensure exists)
# ──────────────────────────────────────────────────────────────────────────────
if ! gh milestone view "$MILESTONE" -R "$REPO" >/dev/null 2>&1; then
  gh milestone create "$MILESTONE" -R "$REPO" --description "All must-do items before go-live"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 5) ISSUE BODIES (heredocs). We create if missing, then tag as high-priority blockers.
# ──────────────────────────────────────────────────────────────────────────────

body_parsing=$(cat <<'EOF'
## Summary
Add a deterministic parsing pipeline to ingest uploaded docs and propose structured fields, with human review before apply.

## Problem / Why
Manual data entry slows onboarding and causes errors. We need a safe, auditable path to speed I-9/W-4/DD using uploads.

## Scope / Acceptance Criteria
- [ ] New `parseJob` model with states: queued|processing|needsReview|applied|failed
- [ ] Integrate OCR (provider or Tesseract): produce text + per-token coordinates
- [ ] Classifier (rules first): passport|stateID|ssCard|w4|voidedCheck|bankLetter|other
- [ ] Field extraction mappers:
      - I-9 docs: type, issuingAuthority, documentNumber, expirationDate, fullName, dob
      - W-4: filingStatus, dependents, otherIncome, deductions, extraWithholding (mask SSN)
      - Direct Deposit: routingNumber (ABA), accountNumber (masked), type if present
- [ ] Confidence scoring and thresholding (<X => needsReview)
- [ ] Review UI: field-by-field accept/correct then apply
- [ ] Apply writes into existing models with audit event `doc.parse.apply`
- [ ] Server validation re-checks business rules prior to apply
- [ ] Metrics: parse success rate, avg OCR time, % needsReview

## Tech Notes
- Provider interface so OCR/classifier can be swapped
- PII handling: originals + derivatives encrypted; previews redacted (see separate issue)
- Events: doc.uploaded → doc.classified → doc.parsed → doc.validated → doc.applied|doc.failed

## Out of Scope
- GenAI/LLM extraction (separate issue)
EOF
)

body_alloc=$(cat <<'EOF'
## Summary
Let employees split pay across multiple accounts by percent, fixed amount, and remainder.

## Scope / Acceptance Criteria
- [ ] Schema: replace `depositAmount` with `allocation: { kind: percent|amount|remainder, value }`
- [ ] Validation: total percent ≤ 100; if no remainder, total percent == 100; max one remainder
- [ ] Validate each routingNumber via ABA checksum; accountNumber length ≥ 4
- [ ] UI supports adding/removing accounts, shows running totals
- [ ] Backward migration from current `depositAmount` semantics
- [ ] Audit event: `dd.submit` includes allocations (masked values)

## Out of Scope
- Bank account verification micro-deposits (future)
EOF
)

body_redact=$(cat <<'EOF'
## Summary
All previews must mask SSN and bank account numbers; raw files remain in secure storage only.

## Scope / Acceptance Criteria
- [ ] Endpoint: GET /api/docs/:id/preview renders redacted image/PDF
- [ ] Mask patterns: SSN (***-**-1234) and account numbers (****1234)
- [ ] Ensure no raw digits appear in logs/telemetry
- [ ] Accessibility: previews support alt text and keyboard focus
- [ ] E2E tests verifying redaction on sample docs

## Tech Notes
- Redaction can use OCR token coordinates or regex on text layers
EOF
)

body_inbox=$(cat <<'EOF'
## Summary
Centralized inbox for managers to complete I-9 Section 2 and review low-confidence parse proposals.

## Scope / Acceptance Criteria
- [ ] List items by employee with statuses: pending S2, needsReview
- [ ] Bulk approve where safe; per-field accept/correct flows
- [ ] Sign Section 2 directly from inbox; enforce role and org checks
- [ ] Audit events for all approvals/rejections
- [ ] Performance: loads in <1s for 100 pending items

## Out of Scope
- SLA/notifications (future)
EOF
)

body_genai=$(cat <<'EOF'
## Summary
Plug-in adapter to use LLMs for doc classification and extraction when templates fail.

## Scope / Acceptance Criteria
- [ ] Provider interface with retries, timeouts, schema validation
- [ ] Prompt templates per doc-type; JSON schema enforced on output
- [ ] Confidence scoring and fallback to human review
- [ ] Strict PII controls; disable training data retention
- [ ] Feature flag: ONBOARDING_PARSER_GENAI=true/false

## Out of Scope
- Making GenAI a hard dependency
EOF
)

body_obs=$(cat <<'EOF'
## Summary
Instrument the onboarding funnel and parsing pipeline.

## Scope / Acceptance Criteria
- [ ] Metrics: time-to-verified, step drop-offs, parse success rate, OCR latency
- [ ] Tracing across upload → parse → apply; correlate by documentId and userId
- [ ] Error rate dashboards per endpoint; alerts on anomalies
- [ ] Logs scrubbed for PII

## Out of Scope
- Vendor migration tooling
EOF
)

body_legal=$(cat <<'EOF'
## Summary
Implement retention schedules per federal rules and secure purge.

## Scope / Acceptance Criteria
- [ ] Immutable W-4 PDF storage with versioning and ACLs
- [ ] I-9 retention timers and purge scheduler with audit
- [ ] Admin report/export for upcoming purges
- [ ] Dry-run mode and cancellation safety
EOF
)

# Map titles → bodies → labels
declare -A BODY_MAP
BODY_MAP["${ISSUE_TITLES[0]}"]="$body_parsing"
BODY_MAP["${ISSUE_TITLES[1]}"]="$body_alloc"
BODY_MAP["${ISSUE_TITLES[2]}"]="$body_redact"
BODY_MAP["${ISSUE_TITLES[3]}"]="$body_inbox"
BODY_MAP["${ISSUE_TITLES[4]}"]="$body_genai"
BODY_MAP["${ISSUE_TITLES[5]}"]="$body_obs"
BODY_MAP["${ISSUE_TITLES[6]}"]="$body_legal"

declare -A LABEL_MAP
LABEL_MAP["${ISSUE_TITLES[0]}"]="enhancement,backend,parsing,PII"
LABEL_MAP["${ISSUE_TITLES[1]}"]="enhancement,backend,payroll"
LABEL_MAP["${ISSUE_TITLES[2]}"]="security,frontend,backend,PII"
LABEL_MAP["${ISSUE_TITLES[3]}"]="enhancement,frontend,backend"
LABEL_MAP["${ISSUE_TITLES[4]}"]="enhancement,ml,parsing"
LABEL_MAP["${ISSUE_TITLES[5]}"]="observability,infra"
LABEL_MAP["${ISSUE_TITLES[6]}"]="compliance,security,backend"

# Helper: create issue if not exists, then tag as priority + milestone
create_or_update_issue () {
  local title="$1"
  local body="${BODY_MAP[$title]}"
  local labels="${LABEL_MAP[$title]}"

  # Check if an open issue with this title already exists
  local num
  num=$(gh issue list -R "$REPO" --state open --search "$title in:title" --json number,title --jq \
      "map(select(.title == \"$title\")) | .[0].number" 2>/dev/null || true)

  if [[ -z "${num:-}" ]]; then
    echo "📝 Creating issue: $title"
    # shellcheck disable=SC2086
    gh issue create -R "$REPO" --title "$title" --body "$body" \
      $(printf -- --label=%s ${labels//,/ }) >/dev/null
    # re-query to get the number
    num=$(gh issue list -R "$REPO" --state open --search "$title in:title" --json number,title --jq \
        "map(select(.title == \"$title\")) | .[0].number")
  else
    echo "ℹ️  Issue already exists (#$num): $title"
  fi

  # Add priority label
  gh issue edit -R "$REPO" "$num" --add-label "$PRIORITY_LABEL" >/dev/null

  # Assign milestone
  gh issue edit -R "$REPO" "$num" --milestone "$MILESTONE" >/dev/null

  # Print final URL
  gh issue view -R "$REPO" "$num" --json url --jq .url
}

echo "▶️  Creating/updating issues, tagging as HIGH PRIORITY, and assigning milestone…"
ISSUE_URLS=()
for t in "${ISSUE_TITLES[@]}"; do
  url=$(create_or_update_issue "$t")
  ISSUE_URLS+=("$url")
done

# ──────────────────────────────────────────────────────────────────────────────
# 6) PUSH BRANCH
# ──────────────────────────────────────────────────────────────────────────────
git push -u origin "$BRANCH"

# ──────────────────────────────────────────────────────────────────────────────
# 7) SUMMARY
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "✅ Done. Issues (all marked \"$PRIORITY_LABEL\" and milestone \"$MILESTONE\"):"
printf ' - %s\n' "${ISSUE_URLS[@]}"

echo ""
echo "🔎 Verify with:"
echo "  gh issue list -R \"$REPO\" --milestone \"$MILESTONE\" --label \"$PRIORITY_LABEL\" --state open --json number,title,labels,url --jq '.[] | {number,title,labels:[.labels[].name],url}'"
