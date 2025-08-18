#!/usr/bin/env bash
set -euo pipefail

ROOT="${PWD}"
echo "Scaffolding Auth + Onboarding into: $ROOT"

# --- directories
mkdir -p client/src/{features/{auth,onboarding},lib}
mkdir -p server/src
mkdir -p firebase

# -------------------- CLIENT --------------------

# Minimal Firebase web init
cat > client/src/lib/firebase.ts <<'EOF'
// client/src/lib/firebase.ts
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
EOF

# Auth hook
cat > client/src/lib/useAuth.ts <<'EOF'
// client/src/lib/useAuth.ts
import { useEffect, useState } from 'react';
import { onAuthStateChanged, User, getIdToken } from 'firebase/auth';
import { auth } from './firebase';

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    return onAuthStateChanged(auth, async (u) => {
      setUser(u);
      setLoading(false);
    });
  }, []);

  async function idToken(): Promise<string|null> {
    if (!auth.currentUser) return null;
    return await getIdToken(auth.currentUser, true);
  }

  return { user, loading, idToken };
}
EOF

# API helper
cat > client/src/lib/api.ts <<'EOF'
// client/src/lib/api.ts
export async function api<T = any>(path: string, opts: RequestInit & { idToken?: string|null } = {}): Promise<T> {
  const { idToken, headers, ...rest } = opts;
  const res = await fetch(path, {
    ...rest,
    headers: {
      'Content-Type': 'application/json',
      ...(headers || {}),
      ...(idToken ? { 'Authorization': `Bearer ${idToken}` } : {}),
    }
  });
  if (!res.ok) {
    let msg = await res.text();
    try { const j = JSON.parse(msg); msg = (j.error || msg); } catch {}
    throw new Error(`${res.status} ${res.statusText}: ${msg}`);
  }
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) return res.json() as Promise<T>;
  // @ts-ignore
  return res.text() as Promise<T>;
}
EOF

# SignIn
cat > client/src/features/auth/SignIn.tsx <<'EOF'
// client/src/features/auth/SignIn.tsx
import { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../../lib/firebase';

export default function SignIn({ onSignedIn }: { onSignedIn?: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null);
    try {
      await signInWithEmailAndPassword(auth, email, password);
      onSignedIn?.();
    } catch (err: any) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} style={{ maxWidth: 360, margin: '40px auto', display: 'grid', gap: 12 }}>
      <h2>Sign in</h2>
      <input placeholder="email" type="email" value={email} onChange={e=>setEmail(e.target.value)} required />
      <input placeholder="password" type="password" value={password} onChange={e=>setPassword(e.target.value)} required />
      {error && <div role="alert" style={{ color: 'crimson' }}>{error}</div>}
      <button disabled={busy} type="submit">{busy ? 'Signing in...' : 'Sign in'}</button>
    </form>
  );
}
EOF

# SignUp
cat > client/src/features/auth/SignUp.tsx <<'EOF'
// client/src/features/auth/SignUp.tsx
import { useState } from 'react';
import { createUserWithEmailAndPassword, updateProfile } from 'firebase/auth';
import { auth } from '../../lib/firebase';

export default function SignUp({ onSignedUp }: { onSignedUp?: () => void }) {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null);
    try {
      const cred = await createUserWithEmailAndPassword(auth, email, password);
      await updateProfile(cred.user, { displayName: [firstName, lastName].filter(Boolean).join(' ') });
      onSignedUp?.();
    } catch (err: any) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} style={{ maxWidth: 420, margin: '40px auto', display: 'grid', gap: 12 }}>
      <h2>Create your account</h2>
      <div style={{ display:'grid', gap:8, gridTemplateColumns:'1fr 1fr' }}>
        <input placeholder="first name" value={firstName} onChange={e=>setFirstName(e.target.value)} required />
        <input placeholder="last name" value={lastName} onChange={e=>setLastName(e.target.value)} required />
      </div>
      <input placeholder="email" type="email" value={email} onChange={e=>setEmail(e.target.value)} required />
      <input placeholder="password" type="password" value={password} onChange={e=>setPassword(e.target.value)} required />
      {error && <div role="alert" style={{ color: 'crimson' }}>{error}</div>}
      <button disabled={busy} type="submit">{busy ? 'Creating...' : 'Create account'}</button>
    </form>
  );
}
EOF

# Onboarding gate (sample)
cat > client/src/features/onboarding/OnboardingGate.tsx <<'EOF'
// client/src/features/onboarding/OnboardingGate.tsx
import { useEffect, useState } from 'react';
import { useAuth } from '../../lib/useAuth';
import { api } from '../../lib/api';

type Me = { uid: string; orgId?: string; role?: 'admin'|'manager'|'staff'; status?: 'pending'|'active'|'inactive' };

export default function OnboardingGate({ onReady }: { onReady?: (me: Me) => void }) {
  const { user, loading, idToken } = useAuth();
  const [me, setMe] = useState<Me | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      if (loading) return;
      if (!user) { setMe(null); return; }
      try {
        const token = await idToken();
        const resp = await api<Me>('/api/me', { idToken: token || undefined });
        setMe(resp);
        onReady?.(resp);
      } catch (e: any) {
        setError(e.message || String(e));
      }
    })();
  }, [user, loading]);

  if (loading) return <p>Loading...</p>;
  if (!user) return <p>Please sign in.</p>;
  if (error) return <p style={{ color: 'crimson' }}>{error}</p>;

  return <div><pre>{JSON.stringify(me, null, 2)}</pre></div>;
}
EOF

# Create Org
cat > client/src/features/onboarding/CreateOrg.tsx <<'EOF'
// client/src/features/onboarding/CreateOrg.tsx
import { useState } from 'react';
import { useAuth } from '../../lib/useAuth';
import { api } from '../../lib/api';

export default function CreateOrg() {
  const { idToken } = useAuth();
  const [name, setName] = useState('');
  const [error, setError] = useState<string|null>(null);
  const [orgId, setOrgId] = useState<string| null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null);
    try {
      const token = await idToken();
      const resp = await api<{ orgId: string }>('/api/orgs', {
        method: 'POST',
        idToken: token || undefined,
        body: JSON.stringify({ name })
      });
      setOrgId(resp.orgId);
    } catch (e: any) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} style={{ maxWidth: 420, margin: '40px auto', display: 'grid', gap: 12 }}>
      <h2>Create your organization</h2>
      <input placeholder="Organization name" value={name} onChange={e=>setName(e.target.value)} required />
      {error && <div role="alert" style={{ color: 'crimson' }}>{error}</div>}
      <button disabled={busy} type="submit">{busy ? 'Creating...' : 'Create org'}</button>
      {orgId && <p>Created org <b>{orgId}</b>. You can now invite managers and staff.</p>}
    </form>
  );
}
EOF

# Join Org
cat > client/src/features/onboarding/JoinOrg.tsx <<'EOF'
// client/src/features/onboarding/JoinOrg.tsx
import { useState } from 'react';
import { useAuth } from '../../lib/useAuth';
import { api } from '../../lib/api';

export default function JoinOrg() {
  const { idToken } = useAuth();
  const [orgId, setOrgId] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [error, setError] = useState<string|null>(null);
  const [ok, setOk] = useState(false);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null); setOk(false);
    try {
      const token = await idToken();
      await api(`/api/orgs/${encodeURIComponent(orgId)}/invites/accept`, {
        method: 'POST',
        idToken: token || undefined,
        body: JSON.stringify({ inviteCode })
      });
      setOk(true);
    } catch (e: any) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} style={{ maxWidth: 420, margin: '40px auto', display: 'grid', gap: 12 }}>
      <h2>Join an organization</h2>
      <input placeholder="Org ID" value={orgId} onChange={e=>setOrgId(e.target.value)} required />
      <input placeholder="Invite code" value={inviteCode} onChange={e=>setInviteCode(e.target.value)} required />
      {error && <div role="alert" style={{ color: 'crimson' }}>{error}</div>}
      <button disabled={busy} type="submit">{busy ? 'Joining...' : 'Join'}</button>
      {ok && <p>Success. Your role and status have been updated.</p>}
    </form>
  );
}
EOF

# Routes (sample)
cat > client/src/routes.tsx <<'EOF'
// client/src/routes.tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import SignIn from './features/auth/SignIn';
import SignUp from './features/auth/SignUp';
import CreateOrg from './features/onboarding/CreateOrg';
import JoinOrg from './features/onboarding/JoinOrg';

export default function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/signin" element={<SignIn onSignedIn={()=>location.assign('/')}/>} />
        <Route path="/signup" element={<SignUp onSignedUp={()=>location.assign('/onboarding')}/>} />
        <Route path="/onboarding/create-org" element={<CreateOrg/>} />
        <Route path="/onboarding/join-org" element={<JoinOrg/>} />
        <Route path="/onboarding" element={<div>
          <h2>Onboarding</h2>
          <ul>
            <li><a href="/onboarding/create-org">Create an org</a></li>
            <li><a href="/onboarding/join-org">Join with invite</a></li>
          </ul>
        </div>} />
        <Route path="/" element={<Navigate to="/onboarding" replace />} />
        <Route path="*" element={<div>Not found</div>} />
      </Routes>
    </BrowserRouter>
  );
}
EOF

# Minimal React entrypoints (if you don't already have them)
mkdir -p client/public
cat > client/index.html <<'EOF'
<!doctype html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>Auth + Onboarding</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

cat > client/src/App.tsx <<'EOF'
import AppRoutes from './routes';
export default function App(){ return <AppRoutes/> }
EOF

cat > client/src/main.tsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode><App/></React.StrictMode>
);
EOF

# Vite + TS configs (safe defaults)
cat > client/package.json <<'EOF'
{
  "name": "auth-onboarding-client",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "vite --port 5173",
    "build": "vite build",
    "preview": "vite preview --port 5173"
  },
  "dependencies": {
    "firebase": "^10.13.1",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.26.2"
  },
  "devDependencies": {
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "typescript": "^5.5.4",
    "vite": "^5.4.2"
  }
}
EOF

cat > client/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023", "DOM", "DOM.Iterable"],
    "jsx": "react-jsx",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true
  },
  "include": ["src"]
}
EOF

cat > client/vite.config.ts <<'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()]
})
EOF

# -------------------- SERVER --------------------

# Firebase Admin init
cat > server/src/firebase.ts <<'EOF'
// server/src/firebase.ts
import admin from 'firebase-admin';

let app: admin.app.App;
if (!admin.apps.length) {
  const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!json) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is required (service account JSON as a single env var).');
  }
  const creds = JSON.parse(json);
  app = admin.initializeApp({
    credential: admin.credential.cert(creds),
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET || undefined
  });
} else {
  app = admin.app();
}

export const auth = admin.auth(app);
export const db = admin.firestore(app);
EOF

# Verify ID token middleware
cat > server/src/auth.ts <<'EOF'
// server/src/auth.ts
import { Request, Response, NextFunction } from 'express';
import { auth } from './firebase';

export async function verifyFirebaseToken(req: Request & { uid?: string }, res: Response, next: NextFunction) {
  const h = req.header('authorization') || req.header('Authorization') || '';
  const m = h.match(/^Bearer\s+(.+)$/i);
  if (!m) return res.status(401).json({ error: 'Missing Bearer token' });
  try {
    const decoded = await auth.verifyIdToken(m[1]);
    req.uid = decoded.uid;
    return next();
  } catch (e: any) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
EOF

# Onboarding routes
cat > server/src/onboarding.ts <<'EOF'
// server/src/onboarding.ts
import express from 'express'
import crypto from 'crypto'
import { db } from './firebase'

export function onboardingRouter(verifyFirebaseToken: any) {
  const r = express.Router()

  // Create organization and make caller admin + active member
  r.post('/orgs', verifyFirebaseToken, async (req: any, res) => {
    const uid = req.uid as string
    const { name } = req.body || {}
    if (!name) return res.status(400).json({ error: 'name required' })

    const orgRef = await db.collection('orgs').add({
      name,
      createdBy: uid,
      createdAt: new Date(),
    })
    const orgId = orgRef.id

    await orgRef.collection('members').doc(uid).set({
      role: 'admin',
      status: 'active',
      createdAt: new Date(),
    }, { merge: true })

    await db.collection('users').doc(uid).set({
      orgId, role: 'admin', status: 'active'
    }, { merge: true })

    res.json({ orgId })
  })

  // Create invites (admin/manager only). Returns a plaintext inviteCode ONCE.
  r.post('/orgs/:orgId/invites', verifyFirebaseToken, async (req: any, res) => {
    const { orgId } = req.params
    const { email, role } = req.body || {}
    if (!email || !role || !['admin','manager','staff'].includes(role)) {
      return res.status(400).json({ error: 'email and role required' })
    }

    // Ensure caller is admin/manager & active
    const caller = await db.collection('orgs').doc(orgId).collection('members').doc(req.uid).get()
    if (!caller.exists) return res.status(403).json({ error: 'not a member' })
    const cRole = caller.get('role'); const cStatus = caller.get('status')
    if (!['admin','manager'].includes(cRole) || cStatus !== 'active') {
      return res.status(403).json({ error: 'forbidden' })
    }

    const token = crypto.randomBytes(16).toString('hex')
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex')

    const ref = db.collection('orgs').doc(orgId).collection('invites').doc()
    await ref.set({
      email: String(email).toLowerCase().trim(),
      role,
      tokenHash,
      status: 'pending',
      createdBy: req.uid,
      createdAt: new Date(),
    })

    res.json({ inviteCode: token, inviteId: ref.id })
  })

  // Accept invite (must be signed in; email must match; becomes active member with role)
  r.post('/orgs/:orgId/invites/accept', verifyFirebaseToken, async (req: any, res) => {
    const { orgId } = req.params
    const { inviteCode } = req.body || {}
    if (!inviteCode) return res.status(400).json({ error: 'inviteCode required' })

    const user = await db.collection('users').doc(req.uid).get()
    const authEmail = (user.get('email') || '').toString().toLowerCase()

    const invitesRef = db.collection('orgs').doc(orgId).collection('invites')
    const tokenHash = crypto.createHash('sha256').update(inviteCode).digest('hex')
    const snap = await invitesRef.where('tokenHash', '==', tokenHash).limit(1).get()
    if (snap.empty) return res.status(404).json({ error: 'invalid invite' })

    const invite = snap.docs[0]
    const invEmail = invite.get('email')
    const role = invite.get('role')
    const status = invite.get('status')
    if (status !== 'pending') return res.status(400).json({ error: 'invite already used' })
    if (!authEmail || authEmail !== invEmail) {
      return res.status(403).json({ error: 'email does not match invite' })
    }

    const batch = db.batch()
    const orgDoc = db.collection('orgs').doc(orgId)
    const memberDoc = orgDoc.collection('members').doc(req.uid)
    batch.set(memberDoc, {
      role, status: 'active', joinedAt: new Date()
    }, { merge: true })

    const userDoc = db.collection('users').doc(req.uid)
    batch.set(userDoc, { orgId, role, status: 'active' }, { merge: true })

    batch.update(invite.ref, { status: 'accepted', acceptedBy: req.uid, acceptedAt: new Date() })
    await batch.commit()

    res.json({ ok: true, orgId, role, status: 'active' })
  })

  return r
}
EOF

# Server index with /api/me
cat > server/src/index.ts <<'EOF'
// server/src/index.ts
import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import bodyParser from 'body-parser'
import { db } from './firebase'
import { verifyFirebaseToken } from './auth'
import { onboardingRouter } from './onboarding'

const app = express()
app.use(cors({ origin: process.env.CORS_ORIGIN?.split(',') || true }))
app.use(bodyParser.json({ limit: '1mb' }))

// whoami
app.get('/api/me', verifyFirebaseToken, async (req: any, res) => {
  const uid = req.uid as string
  const doc = await db.collection('users').doc(uid).get()
  const base = { uid }
  if (!doc.exists) return res.json(base)
  const data = doc.data() || {}
  return res.json({ ...base, orgId: data.orgId, role: data.role, status: data.status })
})

// onboarding APIs
app.use('/api', onboardingRouter(verifyFirebaseToken))

const port = Number(process.env.PORT || 8080)
app.listen(port, () => {
  console.log(`API listening on http://localhost:${port}`)
})
EOF

# Server package + tsconfig + env sample
cat > server/package.json <<'EOF'
{
  "name": "auth-onboarding-server",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "tsx src/index.ts"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "firebase-admin": "^12.6.0",
    "body-parser": "^1.20.2"
  },
  "devDependencies": {
    "tsx": "^4.16.2",
    "typescript": "^5.5.4",
    "@types/express": "^4.17.21"
  }
}
EOF

cat > server/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
EOF

cat > server/.env.sample <<'EOF'
PORT=8080
CORS_ORIGIN=http://localhost:5173
FIREBASE_STORAGE_BUCKET=shyft-xphli.appspot.com
# Put the JSON on one line; keep it SECRET and server-only:
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"shyft-xphli","private_key_id":"<ROTATED>","private_key":"-----BEGIN PRIVATE KEY-----\n<ROTATED>\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-fbsvc@shyft-xphli.iam.gserviceaccount.com","client_id":"107049195366964698204","token_uri":"https://oauth2.googleapis.com/token"}
EOF

# -------------------- FIREBASE RULES (INVITES ADDENDUM) --------------------
cat > firebase/firestore.rules.invites.addendum.txt <<'EOF'
// firebase/firestore.rules (invites addendum)
// Merge into your ruleset. Staff remains read-only; invites are admin/manager only.
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function isSignedIn() { return request.auth != null; }
    function me() { return get(/databases/$(db)/documents/users/$(request.auth.uid)).data; }
    function member(orgId) { return get(/databases/$(db)/documents/orgs/$(orgId)/members/$(request.auth.uid)).data; }
    function isActiveMember(orgId) { return isSignedIn() && member(orgId).status == 'active'; }
    function isAdminOrManager(orgId) {
      let r = member(orgId).role;
      return isActiveMember(orgId) && (r == 'admin' || r == 'manager');
    }

    match /orgs/{orgId}/invites/{inviteId} {
      allow read, write: if isAdminOrManager(orgId);
    }
  }
}
EOF

# -------------------- README --------------------
cat > README_AUTH_ONBOARDING.md <<'EOF'
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
EOF

# -------------------- INSTALL STEPS --------------------
echo "Installing server deps..."
( cd server && npm i >/dev/null 2>&1 || true )

echo "Installing client deps..."
( cd client && npm i >/dev/null 2>&1 || true )

cat <<'DONE'

✅ Scaffolding complete.

Next steps:
1) Server
   cd server
   cp .env.sample .env
   # paste your rotated service account JSON into FIREBASE_SERVICE_ACCOUNT_JSON
   npm run dev

2) Client
   cd client
   # create client/.env with your Firebase web config:
   cat > .env <<ENV
VITE_FIREBASE_API_KEY=YOUR_API_KEY
VITE_FIREBASE_AUTH_DOMAIN=shyft-xphli.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=shyft-xphli
VITE_FIREBASE_STORAGE_BUCKET=shyft-xphli.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=182080370256
VITE_FIREBASE_APP_ID=1:182080370256:web:694739c6949288bb228355
VITE_ENABLE_SW=false
ENV
   npm run dev

3) Firestore rules
   # merge firebase/firestore.rules.invites.addendum.txt into your rules and deploy:
   firebase deploy --only firestore:rules

4) Happy-path test
   - Sign up a user in the client
   - Create org (returns orgId)
   - Create invite (admin/manager)
   - Sign up/in teammate; accept invite with code
   - Confirm /api/me returns uid/orgId/role/status

DONE
