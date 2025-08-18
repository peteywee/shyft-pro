# Shyft — Auth + Onboarding MVP

This repo contains the Authentication & Onboarding slice:
- Firebase Auth (email/password)
- Org creation (creator -> admin/active)
- Invites with single-use code (hash stored)
- Invite acceptance with email match
- `/api/me` identity + org/role/status
- Optional static hosting of built client from Express when `SERVE_STATIC=true`

## Dev URLs
- Client (Vite): http://localhost:5173
- API (Express): http://localhost:8080
- Health: `/healthz`, `/api/health`

See `README_AUTH_ONBOARDING.md` for detailed API and smoke tests.
