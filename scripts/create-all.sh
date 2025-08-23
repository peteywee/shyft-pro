#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./create_all.sh           # create files only if missing
#   ./create_all.sh --force   # overwrite all files with canonical content
#
# Notes:
# - Creates directories as needed.
# - Prints what it creates/skips.
# - Safe to re-run.

FORCE="false"
if [[ "${1:-}" == "--force" ]]; then
  FORCE="true"
fi

write() {
  local path="$1"
  local content="$2"

  mkdir -p "$(dirname "$path")"
  if [[ -e "$path" && "$FORCE" != "true" ]]; then
    echo "⏭  exists, skipped: $path"
    return 0
  fi
  printf "%s" "$content" > "$path"
  echo "✅ wrote: $path"
}

# ---------- FILE CONTENTS ----------

read -r -d '' FILE_README <<"EOF"
# Shyft (Single-Project PWA)

Secure staff scheduling & onboarding PWA using **Next.js + Firebase (Auth/Firestore)** with an optional **Cloudflare Worker** backend for sensitive/AI tasks.

## Quickstart

### 1) Prereqs
- Node.js ≥ 18
- Firebase project created
- (Optional) Cloudflare account for Worker

### 2) Environment
Create `.env.local` at project root:
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
NEXT_PUBLIC_FIREBASE_APP_ID=...

perl
Copy
Edit

### 3) Install & Run
```bash
npm i
npm run dev
4) Firebase Console Checklist
Auth → Sign-in method: Enable Email/Password and Google.

Auth → Settings → Authorized domains: add localhost, staging, prod domains.

Firestore: publish firestore.rules.

5) (Optional) Cloudflare Worker
bash
Copy
Edit
cd cloudflare-worker
wrangler secret put OPENAI_API_KEY
# set FIREBASE_PROJECT_ID in wrangler.toml
npm run deploy:worker
Structure
bash
Copy
Edit
.
├─ README.md
├─ docs/
│  ├─ IMPLEMENTATION.md
│  └─ SECURITY.md
├─ firestore.rules
├─ next.config.ts
├─ package.json
├─ public/manifest.json
├─ src/
│  ├─ lib/firebase.ts
│  └─ app/
│     ├─ (auth)/login/page.tsx
│     ├─ (auth)/signup/page.tsx
│     ├─ (auth)/organization-setup/page.tsx
│     └─ (app)/
│        ├─ dashboard/page.tsx
│        ├─ onboarding/page.tsx
│        └─ schedule-assistant/
│           ├─ actions.ts
│           └─ page.tsx
└─ cloudflare-worker/
   ├─ wrangler.toml
   └─ src/
      ├─ index.ts
      └─ verifyAuth.ts
Status
See docs/IMPLEMENTATION.md.

Security
See docs/SECURITY.md.
EOF

read -r -d '' FILE_IMPLEMENTATION <<"EOF"

Implementation Notes
Data Model
users/{uid}
name, email

role: 'Admin' | 'Staff' | null

orgId: string | null

onboardingComplete: boolean

onboardingCompletedAt?: number

W‑4/I‑9 fields:

fullName, address, filingStatus, dependentsAmount, otherIncome, otherDeductions, extraWithholding, isMultipleJobsChecked, documentType, documentNumber

createdAt: number

organizations/{orgId}
name

ownerUid

createdAt

invites/{code}
orgId

role

email? (optional binding)

used: boolean

usedBy?: uid

usedAt?: number

createdAt

Pages
signup: real account creation; dev allow-list; create users/{uid}.

login: email/pass; Google redirect; reset password.

organization-setup: create org (Admin) or join via invite (role/orgId).

onboarding: persist fields; set onboardingComplete=true.

dashboard: redirect to onboarding until complete.

schedule-assistant: Admin-only, enforced by Firestore role.

Firestore Rules (summary)
Users can update their profile but not role/orgId.

Org writes restricted to admins within same org.

Invites: admin writes; reads can be public or moved server-side.

Worker (summary)
Endpoint: /api/schedule

Auth: Firebase ID token in Authorization header

Verifies token (iss/aud/exp), checks role, calls AI with secret.
EOF

read -r -d '' FILE_SECURITY <<"EOF"

SECURITY
See high-level policy:

Auth via Firebase; dev allow-list; Google provider.

RBAC via Firestore (role/orgId) + optional custom claims.

Onboarding gating (onboardingComplete).

Cloudflare Worker verifies ID token; secrets never in client.

Firestore rules prevent role/orgId tampering.

Authorized domains set for Google OAuth.

Threats & mitigations:

Token theft → HTTPS, short expiry, server verification.

Privilege escalation → rules + backend checks.

Secret leakage → Worker secrets.

Invite abuse → code usage flags, optional email binding & expiry.
EOF

read -r -d '' FILE_RULES <<"EOF"
rules_version = '2';
service cloud.firestore {
match /databases/{database}/documents {

pgsql
Copy
Edit
match /users/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId
              || request.auth.token.role == 'Admin';
  allow create: if request.auth != null && request.auth.uid == userId;
  allow update: if request.auth != null && request.auth.uid == userId
    && !('role' in request.resource.data.diff(resource.data).changedKeys())
    && !('orgId' in request.resource.data.diff(resource.data).changedKeys());
}

match /organizations/{orgId} {
  allow read: if request.auth != null
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.orgId == orgId;

  allow write: if request.auth != null
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.orgId == orgId
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'Admin';
}

match /invites/{code} {
  allow read: if true;
  allow create, update, delete: if request.auth != null
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'Admin';
}

match /organizations/{orgId}/schedules/{scheduleId} {
  allow read: if request.auth != null
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.orgId == orgId;

  allow write: if request.auth != null
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.orgId == orgId
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'Admin';
}
}
}
EOF

read -r -d '' FILE_NEXTCONFIG <<"EOF"
const withPWA = require('next-pwa')({
dest: 'public',
disable: process.env.NODE_ENV === 'development',
});
module.exports = withPWA({
reactStrictMode: true,
});
EOF

read -r -d '' FILE_PACKAGEJSON <<"EOF"
{
"name": "shyft",
"version": "0.1.0",
"private": true,
"description": "Shyft – Staff scheduling and onboarding PWA with Firebase + Cloudflare Worker backend",
"scripts": {
"dev": "next dev -p 3000",
"build": "next build",
"start": "next start -p 3000",
"lint": "next lint",
"type-check": "tsc --noEmit",
"firebase:emulators": "firebase emulators:start --only auth,firestore,storage",
"firebase:deploy": "firebase deploy --only hosting,firestore,auth,storage",
"deploy:worker": "cd cloudflare-worker && wrangler publish",
"scaffold": "bash ./create_all.sh"
},
"dependencies": {
"firebase": "^10.12.0",
"next": "14.2.5",
"next-pwa": "^5.6.0",
"react": "18.2.0",
"react-dom": "18.2.0"
},
"devDependencies": {
"@types/node": "^20.11.24",
"@types/react": "^18.2.22",
"@types/react-dom": "^18.2.7",
"eslint": "^8.56.0",
"eslint-config-next": "14.2.5",
"typescript": "^5.5.4"
},
"engines": {
"node": ">=18.0.0"
},
"license": "MIT",
"author": "Top Shelf Service LLC"
}
EOF

read -r -d '' FILE_MANIFEST <<"EOF"
{
"name": "Shyft",
"short_name": "Shyft",
"description": "Compliance-first scheduling PWA with secure onboarding.",
"start_url": "/",
"display": "standalone",
"theme_color": "#0f172a",
"background_color": "#ffffff",
"icons": [
{ "src": "/icons/manifest-icon-192.png", "sizes": "192x192", "type": "image/png" },
{ "src": "/icons/manifest-icon-512.png", "sizes": "512x512", "type": "image/png" }
]
}
EOF

read -r -d '' FILE_FIREBASETS <<"EOF"
import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY!,
authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN!,
projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID!,
storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET!,
messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID!,
appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID!,
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
EOF

read -r -d '' FILE_SIGNUP <<"EOF"
'use client';
import * as React from 'react';
import { useRouter } from 'next/navigation';
import { createUserWithEmailAndPassword } from 'firebase/auth';
import { doc, setDoc } from 'firebase/firestore';
import { auth, db } from '@/lib/firebase';

const DEV_ALLOWED = ['cravenwspatrick@gmail.com'];

export default function SignupPage() {
const router = useRouter();
const [name, setName] = React.useState('');
const [email, setEmail] = React.useState('');
const [password, setPassword] = React.useState('');
const [inviteCode, setInviteCode] = React.useState('');
const [loading, setLoading] = React.useState(false);
const [error, setError] = React.useState<string|null>(null);

const onSubmit = async (e: React.FormEvent) => {
e.preventDefault(); setError(null);
if (!name || !email || !password) { setError('All fields are required.'); return; }
if (process.env.NODE_ENV !== 'production' && !DEV_ALLOWED.includes(email)) {
setError('Sign-ups restricted during development.'); return;
}
try {
setLoading(true);
const cred = await createUserWithEmailAndPassword(auth, email, password);
await setDoc(doc(db, 'users', cred.user.uid), {
name, email, role: null, orgId: null, onboardingComplete: false, createdAt: Date.now(),
});
router.push('/organization-setup');
} catch (err: any) {
setError(err?.message || 'Signup failed.');
} finally { setLoading(false); }
};

return (
<main className="max-w-md mx-auto p-6">
<h1 className="text-2xl font-semibold mb-4">Create your account</h1>
<form onSubmit={onSubmit} className="space-y-4">
{error && <p className="text-red-600 text-sm">{error}</p>}
<div><label className="block text-sm">Full name</label>
<input className="w-full border p-2 rounded" value={name} onChange={e=>setName(e.target.value)} /></div>
<div><label className="block text-sm">Email</label>
<input type="email" className="w-full border p-2 rounded" value={email} onChange={e=>setEmail(e.target.value)} /></div>
<div><label className="block text-sm">Password</label>
<input type="password" className="w-full border p-2 rounded" value={password} onChange={e=>setPassword(e.target.value)} /></div>
<div><label className="block text-sm">Invitation Code (required in prod)</label>
<input className="w-full border p-2 rounded" value={inviteCode} onChange={e=>setInviteCode(e.target.value)} /></div>
<button disabled={loading} className="w-full bg-black text-white p-2 rounded">
{loading ? 'Creating...' : 'Sign up'}</button>
</form>
</main>
);
}
EOF

read -r -d '' FILE_LOGIN <<"EOF"
'use client';
import * as React from 'react';
import { useRouter } from 'next/navigation';
import { signInWithEmailAndPassword, sendPasswordResetEmail, GoogleAuthProvider, signInWithRedirect, getRedirectResult } from 'firebase/auth';
import { auth } from '@/lib/firebase';

export default function LoginPage() {
const router = useRouter();
const [email, setEmail] = React.useState('');
const [password, setPassword] = React.useState('');
const [loading, setLoading] = React.useState(false);
const [error, setError] = React.useState<string|null>(null);

React.useEffect(() => {
getRedirectResult(auth).then(res => { if (res?.user) router.push('/dashboard'); })
.catch(err => setError(err?.message || 'Google sign-in failed.'));
}, [router]);

const onSubmit = async (e: React.FormEvent) => {
e.preventDefault(); setError(null);
if (!email || !password) { setError('Email and password required.'); return; }
try {
setLoading(true);
await signInWithEmailAndPassword(auth, email, password);
router.push('/dashboard');
} catch (err: any) { setError(err?.message || 'Login failed.'); }
finally { setLoading(false); }
};

const onGoogle = () => { const provider = new GoogleAuthProvider(); signInWithRedirect(auth, provider); };

const onForgot = async () => {
setError(null);
if (!email) { setError('Enter your email to reset password.'); return; }
try { await sendPasswordResetEmail(auth, email); alert(Password reset link sent to ${email}); }
catch (err: any) { setError(err?.message || 'Reset failed.'); }
};

return (
<main className="max-w-md mx-auto p-6">
<h1 className="text-2xl font-semibold mb-4">Sign in</h1>
<form onSubmit={onSubmit} className="space-y-4">
{error && <p className="text-red-600 text-sm">{error}</p>}
<div><label className="block text-sm">Email</label>
<input type="email" className="w-full border p-2 rounded" value={email} onChange={e=>setEmail(e.target.value)} /></div>
<div><label className="block text-sm">Password</label>
<input type="password" className="w-full border p-2 rounded" value={password} onChange={e=>setPassword(e.target.value)} /></div>
<button disabled={loading} className="w-full bg-black text-white p-2 rounded">{loading ? 'Signing in...' : 'Sign in'}</button>
</form>
<button onClick={onGoogle} className="w-full mt-3 border p-2 rounded">Sign in with Google</button>
<button onClick={onForgot} className="w-full mt-3 text-sm underline">Forgot password?</button>
</main>
);
}
EOF

read -r -d '' FILE_ORGSETUP <<"EOF"
'use client';
import * as React from 'react';
import { useRouter } from 'next/navigation';
import { auth, db } from '@/lib/firebase';
import { addDoc, collection, doc, getDoc, updateDoc } from 'firebase/firestore';

export default function OrganizationSetupPage() {
const router = useRouter();
const [inviteCode, setInviteCode] = React.useState('');
const [loading, setLoading] = React.useState(false);
const [error, setError] = React.useState<string|null>(null);

const onCreateOrg = async () => {
setError(null);
const user = auth.currentUser; if (!user) { setError('Not authenticated.'); return; }
try {
setLoading(true);
const orgRef = await addDoc(collection(db, 'organizations'), {
name: ${user.email?.split('@')[0]}'s Workspace,
ownerUid: user.uid, createdAt: Date.now(),
});
await updateDoc(doc(db, 'users', user.uid), { role: 'Admin', orgId: orgRef.id });
router.push('/onboarding');
} catch (err: any) { setError(err?.message || 'Failed to create organization.'); }
finally { setLoading(false); }
};

const onJoinOrg = async () => {
setError(null);
const user = auth.currentUser; if (!user) { setError('Not authenticated.'); return; }
if (!inviteCode) { setError('Invitation code required.'); return; }

typescript
Copy
Edit
try {
  setLoading(true);
  const inviteSnap = await getDoc(doc(db, 'invites', inviteCode));
  if (!inviteSnap.exists()) throw new Error('Invalid invite code.');
  const { orgId, role = 'Staff', used = false } = inviteSnap.data() || {};
  if (used) throw new Error('Invite already used.');

  await updateDoc(doc(db, 'users', user.uid), { role, orgId });
  await updateDoc(doc(db, 'invites', inviteCode), { used: true, usedBy: user.uid, usedAt: Date.now() });
  router.push('/onboarding');
} catch (err: any) { setError(err?.message || 'Failed to join organization.'); }
finally { setLoading(false); }
};

return (
<main className="max-w-md mx-auto p-6">
<h1 className="text-2xl font-semibold mb-4">Organization Setup</h1>
{error && <p className="text-red-600 text-sm mb-3">{error}</p>}
<div className="space-y-3">
<button disabled={loading} onClick={onCreateOrg} className="w-full bg-black text-white p-2 rounded">
{loading ? 'Working...' : 'Create a new organization (Admin)'}
</button>
<div className="border rounded p-3 space-y-2">
<label className="block text-sm">Invitation Code</label>
<input className="w-full border p-2 rounded" value={inviteCode} onChange={e=>setInviteCode(e.target.value)} />
<button disabled={loading} onClick={onJoinOrg} className="w-full border p-2 rounded">
Join existing organization (Staff)
</button>
</div>
</div>
</main>
);
}
EOF

read -r -d '' FILE_ONBOARD <<"EOF"
'use client';
import * as React from 'react';
import { useRouter } from 'next/navigation';
import { auth, db } from '@/lib/firebase';
import { doc, getDoc, updateDoc } from 'firebase/firestore';

type OnboardingData = {
fullName: string; address: string; filingStatus: 'Single'|'Married'|'HeadOfHousehold';
dependentsAmount: number; otherIncome: number; otherDeductions: number; extraWithholding: number;
isMultipleJobsChecked: boolean; documentType: 'Passport'|'DriverLicense'|'StateID'; documentNumber: string;
};

export default function OnboardingPage() {
const router = useRouter();
const [data, setData] = React.useState<OnboardingData>({
fullName: '', address: '', filingStatus: 'Single', dependentsAmount: 0, otherIncome: 0,
otherDeductions: 0, extraWithholding: 0, isMultipleJobsChecked: false, documentType: 'Passport', documentNumber: '',
});
const [error, setError] = React.useState<string|null>(null); const [saving, setSaving] = React.useState(false);

React.useEffect(() => { (async () => {
const u = auth.currentUser; if (!u) return;
const snap = await getDoc(doc(db, 'users', u.uid));
if (snap.exists() && snap.data().onboardingComplete) router.replace('/dashboard');
})(); }, [router]);

const onSubmit = async (e: React.FormEvent) => {
e.preventDefault(); setError(null);
const u = auth.currentUser; if (!u) { setError('Not authenticated.'); return; }
try {
setSaving(true);
await updateDoc(doc(db, 'users', u.uid), { ...data, onboardingComplete: true, onboardingCompletedAt: Date.now() });
router.push('/dashboard');
} catch (err: any) { setError(err?.message || 'Failed to save onboarding.'); }
finally { setSaving(false); }
};

return (
<main className="max-w-2xl mx-auto p-6">
<h1 className="text-2xl font-semibold mb-4">Complete your onboarding</h1>
{error && <p className="text-red-600 text-sm mb-3">{error}</p>}
<form onSubmit={onSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-4">
<div><label className="block text-sm">Full Name</label>
<input className="w-full border p-2 rounded" value={data.fullName} onChange={e=>setData({...data, fullName: e.target.value})}/></div>
<div><label className="block text-sm">Address</label>
<input className="w-full border p-2 rounded" value={data.address} onChange={e=>setData({...data, address: e.target.value})}/></div>
<div><label className="block text-sm">Filing Status</label>
<select className="w-full border p-2 rounded" value={data.filingStatus} onChange={e=>setData({...data, filingStatus: e.target.value as any})}>
<option>Single</option><option>Married</option><option>HeadOfHousehold</option></select></div>
<div><label className="block text-sm">Dependents Amount</label>
<input type="number" className="w-full border p-2 rounded" value={data.dependentsAmount} onChange={e=>setData({...data, dependentsAmount: Number(e.target.value)})}/></div>
<div><label className="block text-sm">Other Income</label>
<input type="number" className="w-full border p-2 rounded" value={data.otherIncome} onChange={e=>setData({...data, otherIncome: Number(e.target.value)})}/></div>
<div><label className="block text-sm">Other Deductions</label>
<input type="number" className="w-full border p-2 rounded" value={data.otherDeductions} onChange={e=>setData({...data, otherDeductions: Number(e.target.value)})}/></div>
<div><label className="block text-sm">Extra Withholding</label>
<input type="number" className="w-full border p-2 rounded" value={data.extraWithholding} onChange={e=>setData({...data, extraWithholding: Number(e.target.value)})}/></div>
<div className="flex items-center gap-2">
<input id="multi" type="checkbox" checked={data.isMultipleJobsChecked} onChange={e=>setData({...data, isMultipleJobsChecked: e.target.checked})}/>
<label htmlFor="multi" className="text-sm">Multiple Jobs/Spouse Works</label></div>
<div><label className="block text-sm">Document Type</label>
<select className="w-full border p-2 rounded" value={data.documentType} onChange={e=>setData({...data, documentType: e.target.value as any})}>
<option>Passport</option><option>DriverLicense</option><option>StateID</option></select></div>
<div><label className="block text-sm">Document Number</label>
<input className="w-full border p-2 rounded" value={data.documentNumber} onChange={e=>setData({...data, documentNumber: e.target.value})}/></div>
<div className="col-span-full">
<button disabled={saving} className="w-full bg-black text-white p-2 rounded">{saving ? 'Saving...' : 'Finish Onboarding'}</button>
</div>
</form>
</main>
);
}
EOF

read -r -d '' FILE_DASH <<"EOF"
'use client';
import * as React from 'react';
import { useRouter } from 'next/navigation';
import { auth, db } from '@/lib/firebase';
import { doc, getDoc } from 'firebase/firestore';

export default function DashboardPage() {
const router = useRouter();
const [ready, setReady] = React.useState(false);

React.useEffect(() => { (async () => {
const u = auth.currentUser; if (!u) { router.replace('/login'); return; }
const snap = await getDoc(doc(db, 'users', u.uid)); const data = snap.data();
if (!data?.onboardingComplete) { router.replace('/onboarding'); return; }
setReady(true);
})(); }, [router]);

if (!ready) return null;
return (<main className="p-6"><h1 className="text-2xl font-semibold">Dashboard</h1></main>);
}
EOF

read -r -d '' FILE_SA_PAGE <<"EOF"
'use client';
import * as React from 'react';
import { useRouter } from 'next/navigation';
import { auth, db } from '@/lib/firebase';
import { doc, getDoc } from 'firebase/firestore';
import { generateSchedule } from './actions';

export default function ScheduleAssistantPage() {
const router = useRouter();
const [authorized, setAuthorized] = React.useState<boolean | null>(null);
const [input, setInput] = React.useState<any>({ employees: [], constraints: {} });
const [out, setOut] = React.useState<any>(null);

React.useEffect(() => { (async () => {
const u = auth.currentUser; if (!u) { router.replace('/login'); return; }
const snap = await getDoc(doc(db, 'users', u.uid)); const data = snap.data();
if (!data?.onboardingComplete) { router.replace('/onboarding'); return; }
if (data?.role !== 'Admin') { alert('Access denied: Admins only.'); router.replace('/dashboard'); return; }
setAuthorized(true);
})(); }, [router]);

const onRun = async () => {
try { const res = await generateSchedule(input); setOut(res); }
catch (e: any) { alert(e.message || 'Schedule generation failed'); }
};

if (!authorized) return null;
return (
<main className="p-6">
<h1 className="text-2xl font-semibold mb-4">AI Schedule Assistant</h1>
<textarea className="w-full border p-2 rounded h-32" placeholder="JSON constraints…" onChange={e=>setInput(JSON.parse(e.target.value || '{}'))}/>
<button className="mt-3 border p-2 rounded" onClick={onRun}>Generate</button>
{out && <pre className="mt-4 p-3 bg-gray-100 rounded text-sm overflow-auto">{JSON.stringify(out, null, 2)}</pre>}
</main>
);
}
EOF

read -r -d '' FILE_SA_ACTIONS <<"EOF"
'use client';
import { auth } from '@/lib/firebase';

export async function generateSchedule(input: any) {
const u = auth.currentUser; if (!u) throw new Error('Not authenticated');
const token = await u.getIdToken();
const res = await fetch('/api/schedule', {
method: 'POST',
headers: { 'Authorization': Bearer ${token} },
body: JSON.stringify(input),
});
if (!res.ok) throw new Error(await res.text());
return res.json();
}
EOF

read -r -d '' FILE_WRANGLER <<"EOF"
name = "shyft-backend-worker"
main = "src/index.ts"
compatibility_date = "2025-08-23"
account_id = "YOUR_CLOUDFLARE_ACCOUNT_ID"

[vars]
FIREBASE_PROJECT_ID = "YOUR_FIREBASE_PROJECT_ID"
EOF

read -r -d '' FILE_VERIFYAUTH <<"EOF"
export async function verifyFirebaseToken(idToken: string, projectId: string): Promise<Record<string, any>> {
const [h, p, s] = idToken.split('.'); if (!h || !p || !s) throw new Error('Invalid JWT');
const dec = (x: string) => JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(x.replace(/-/g,'+').replace(//g,'/')), c=>c.charCodeAt(0))));
const header = dec(h); const payload = dec(p); const sig = Uint8Array.from(atob(s.replace(/-/g,'+').replace(//g,'/')), c=>c.charCodeAt(0));
const resp = await fetch('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com', { cf: { cacheTtl: 300, cacheEverything: true }});
if (!resp.ok) throw new Error('certs fetch failed'); const certs = await resp.json() as Record<string,string>;
const pem = certs[header.kid]; if (!pem) throw new Error('unknown kid');
const b64 = pem.replace('-----BEGIN CERTIFICATE-----','').replace('-----END CERTIFICATE-----','').replace(/\s+/g,'');
const der = Uint8Array.from(atob(b64), c=>c.charCodeAt(0));
const key = await crypto.subtle.importKey('spki', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
const ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, sig, new TextEncoder().encode(${h}.${p}));
if (!ok) throw new Error('bad signature');
const now = Math.floor(Date.now()/1000);
if (payload.aud !== projectId) throw new Error('bad aud');
if (payload.iss !== https://securetoken.google.com/${projectId}) throw new Error('bad iss');
if (payload.exp < now) throw new Error('expired');
return payload;
}
EOF

read -r -d '' FILE_WORKER_INDEX <<"EOF"
import { verifyFirebaseToken } from './verifyAuth';

export interface Env {
FIREBASE_PROJECT_ID: string;
OPENAI_API_KEY: string;
}

async function json(req: Request) {
try { return await req.json(); } catch { return null; }
}

async function handleSchedule(req: Request, env: Env) {
const authHeader = req.headers.get('Authorization') || '';
if (!authHeader.startsWith('Bearer ')) return new Response('Unauthorized', { status: 401 });
const token = authHeader.substring(7);

let payload: any;
try { payload = await verifyFirebaseToken(token, env.FIREBASE_PROJECT_ID); }
catch (err: any) { return new Response(Unauthorized: ${err.message}, { status: 401 }); }

if (payload.role !== 'Admin') return new Response('Forbidden', { status: 403 });

const body = await json(req); if (!body) return new Response('Bad Request', { status: 400 });

const r = await fetch('https://api.openai.com/v1/chat/completions', {
method: 'POST',
headers: { 'Authorization': Bearer ${env.OPENAI_API_KEY}, 'Content-Type': 'application/json' },
body: JSON.stringify({
model: 'gpt-4o-mini',
messages: [
{ role: 'system', content: 'You are a schedule assistant.' },
{ role: 'user', content: Make a schedule with constraints: ${JSON.stringify(body)} }
],
}),
});
if (!r.ok) return new Response(AI error: ${await r.text()}, { status: 502 });
return new Response(await r.text(), { status: 200, headers: { 'Content-Type': 'application/json' } });
}

export default {
async fetch(req: Request, env: Env): Promise<Response> {
const url = new URL(req.url);
if (req.method === 'POST' && url.pathname === '/api/schedule') return handleSchedule(req, env);
return new Response('Not Found', { status: 404 });
}
};
EOF

---------- WRITE FILES ----------
write "README.md" "$FILE_README"
write "docs/IMPLEMENTATION.md" "$FILE_IMPLEMENTATION"
write "docs/SECURITY.md" "$FILE_SECURITY"
write "firestore.rules" "$FILE_RULES"
write "next.config.ts" "$FILE_NEXTCONFIG"
write "package.json" "$FILE_PACKAGEJSON"
write "public/manifest.json" "$FILE_MANIFEST"

write "src/lib/firebase.ts" "$FILE_FIREBASETS"
write "src/app/(auth)/signup/page.tsx" "$FILE_SIGNUP"
write "src/app/(auth)/login/page.tsx" "$FILE_LOGIN"
write "src/app/(auth)/organization-setup/page.tsx" "$FILE_ORGSETUP"
write "src/app/(app)/onboarding/page.tsx" "$FILE_ONBOARD"
write "src/app/(app)/dashboard/page.tsx" "$FILE_DASH"
write "src/app/(app)/schedule-assistant/page.tsx" "$FILE_SA_PAGE"
write "src/app/(app)/schedule-assistant/actions.ts" "$FILE_SA_ACTIONS"

write "cloudflare-worker/wrangler.toml" "$FILE_WRANGLER"
write "cloudflare-worker/src/verifyAuth.ts" "$FILE_VERIFYAUTH"
write "cloudflare-worker/src/index.ts" "$FILE_WORKER_INDEX"

echo ""
echo "All done."
echo "Next steps:"
echo " 1) Populate .env.local with your Firebase web config"
echo " 2) firebase deploy rules or run emulators"
echo " 3) cd cloudflare-worker && wrangler secret put OPENAI_API_KEY"
echo " 4) npm run dev"
EOF

---------- END OF SCRIPT ----------
