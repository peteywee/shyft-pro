# Firebase Studio

This is a NextJS starter in Firebase Studio.

To get started, take a look at src/app/page.tsx.


## Auth & Onboarding (dev)
- `/api/auth/session` issues a dev-only `sid` cookie (httpOnly, 14d). An allowlist is enforced via `src/lib/allowlist.ts`.
- `middleware.ts` protects non-public routes and redirects to `/login` when `sid` is absent.
- Onboarding completion rules live in `src/lib/onboarding/state.ts`. Replace in-memory cache with Redis and snapshots with Firestore in production.
- Client Firebase (if used) remains in `src/services/firebase.ts`. For SSR checks, prefer the `sid` dev cookie while wiring real auth later.


## Firebase Auth (Google) – server verification
Set these env vars in your runtime for Firebase Admin:
- FIREBASE_PROJECT_ID
- FIREBASE_CLIENT_EMAIL
- FIREBASE_PRIVATE_KEY  (escape newlines or provide as multiline secret)

Client uses Firebase Web SDK; on Google popup success we POST the ID token to `/api/auth/firebase/login`,
which verifies the token and sets the httpOnly `sid` cookie (mapped to uid).

Logout: ` + "`POST /api/auth/logout`" + ` clears the cookie.

Onboarding flow can use ` + "`GET /api/auth/me`" + ` to retrieve `{ state.nextStep }` from `evaluateCompletion()`
and redirect users to the next required step.
