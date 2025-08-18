# Auth + Onboarding (Firebase Auth + Firestore RBAC)

Scope:
- Email/password sign-up & sign-in
- Create org (caller -> admin/active)
- Invite by email (one-time code, SHA-256 stored)
- Accept invite (email match) -> active member with role
- /api/me returns uid/orgId/role/status

## Client
- React + Vite + Firebase web SDK
- Files under client/src/...

## Server
- Express + Firebase Admin
- Env: FIREBASE_SERVICE_ACCOUNT_JSON (server-only), PORT, CORS_ORIGIN

## Endpoints
POST /api/orgs
POST /api/orgs/:orgId/invites
POST /api/orgs/:orgId/invites/accept
GET  /api/me

## Quick start
cd server && cp .env.sample .env && npm i && npm run dev
cd client && npm i && npm run dev

## Smoke test (curl)
# after signing in from the client, get an ID token for the user
ADMIN_TOKEN="eyJhbGciOi..."   # admin user
ORG_ID="$(curl -sS -X POST http://localhost:8080/api/orgs -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"name":"Acme Co"}' | jq -r .orgId)"
INVITE_JSON="$(curl -sS -X POST http://localhost:8080/api/orgs/$ORG_ID/invites -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"email":"teammate@example.com","role":"staff"}')"
INVITE_CODE="$(echo "$INVITE_JSON" | jq -r .inviteCode)"

TEAMMATE_TOKEN="eyJhbGciOi..." # token after teammate signs up & signs in
curl -sS -X POST http://localhost:8080/api/orgs/$ORG_ID/invites/accept \
  -H "Authorization: Bearer $TEAMMATE_TOKEN" -H "Content-Type: application/json" \
  -d "{\"inviteCode\":\"$INVITE_CODE\"}"
