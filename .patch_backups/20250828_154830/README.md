# Firebase Studio

This is a NextJS starter in Firebase Studio.

To get started, take a look at src/app/page.tsx.


## Auth & Onboarding (dev)
- `/api/auth/session` issues a dev-only `sid` cookie (httpOnly, 14d). An allowlist is enforced via `src/lib/allowlist.ts`.
- `middleware.ts` protects non-public routes and redirects to `/login` when `sid` is absent.
- Onboarding completion rules live in `src/lib/onboarding/state.ts`. Replace in-memory cache with Redis and snapshots with Firestore in production.
- Client Firebase (if used) remains in `src/services/firebase.ts`. For SSR checks, prefer the `sid` dev cookie while wiring real auth later.
