#!/usr/bin/env bash
set -euo pipefail

# --- sanity ---
[ -f package.json ] || { echo "Run from your Next.js project root (package.json not found)."; exit 1; }

# --- dirs ---
mkdir -p scripts 'app/(auth)/login' 'app/(onboarding)/onboarding' app/api/session app/api/onboarding app/dashboard lib app

# --- .env.local.example ---
cat > .env.local.example <<'EOF'
# ===== Firebase Web (client) =====
NEXT_PUBLIC_FIREBASE_API_KEY=your-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-project-id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=1234567890
NEXT_PUBLIC_FIREBASE_APP_ID=1:1234567890:web:abcdef123456

# ===== Admin (server) =====
# Option A: raw fields
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxx@your-project-id.iam.gserviceaccount.com
# Escape newlines as \n
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nABC123...\n-----END PRIVATE KEY-----\n"

# Option B: base64 of service account JSON (new-key.json)
# If set, FIREBASE_* above are ignored by lib/firebase-admin.ts
FIREBASE_SERVICE_ACCOUNT_B64=
EOF

# --- scripts/load-firebase-admin.sh ---
cat > scripts/load-firebase-admin.sh <<'EOF'
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
EOF
chmod +x scripts/load-firebase-admin.sh

# --- lib/firebase-client.ts ---
cat > lib/firebase-client.ts <<'EOF'
// Client SDK (browser). Uses NEXT_PUBLIC_* envs.
import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth, GoogleAuthProvider } from "firebase/auth";

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
export const googleProvider = new GoogleAuthProvider();
export default app;
EOF

# --- lib/firebase-admin.ts ---
cat > lib/firebase-admin.ts <<'EOF'
// Server SDK (Node). Safe for server components, route handlers, and actions.
import { cert, getApps, initializeApp, App } from "firebase-admin/app";
import { getAuth as getAdminAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

let adminApp: App;

function getServiceAccount(): Record<string, any> {
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64;
  if (b64 && b64.length > 0) {
    return JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
  }
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Firebase Admin env not configured.");
  }
  privateKey = privateKey.replace(/\\n/g, "\n");
  return { project_id: projectId, client_email: clientEmail, private_key: privateKey };
}

if (!getApps().length) {
  const sa = getServiceAccount();
  adminApp = initializeApp({ credential: cert(sa as any) });
} else {
  adminApp = getApps()[0]!;
}

export const adminAuth = getAdminAuth(adminApp);
export const db = getFirestore(adminApp);
EOF

# --- app/(auth)/login/page.tsx ---
cat > 'app/(auth)/login/page.tsx' <<'EOF'
"use client";

import { useEffect, useState } from "react";
import { auth, googleProvider } from "@/lib/firebase-client";
import {
  signInWithPopup,
  signInWithEmailAndPassword,
  onAuthStateChanged,
} from "firebase/auth";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [pass, setPass] = useState("");
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const qp = useSearchParams();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;
      const idToken = await user.getIdToken();
      const r = await fetch("/api/session", { headers: { authorization: `Bearer ${idToken}` }, cache: "no-store" });
      const { onboardingComplete } = await r.json();
      if (onboardingComplete) router.replace(qp.get("next") || "/dashboard");
      else router.replace("/onboarding");
    });
    return () => unsub();
  }, [router, qp]);

  const loginGoogle = async () => {
    try {
      setError(null);
      await signInWithPopup(auth, googleProvider);
    } catch (e: any) {
      setError(e.message || "Google sign-in failed.");
    }
  };

  const loginEmail = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setError(null);
      await signInWithEmailAndPassword(auth, email, pass);
    } catch (err: any) {
      setError(err.message || "Email sign-in failed.");
    }
  };

  return (
    <main className="max-w-md mx-auto p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Sign in</h1>

      <button
        onClick={loginGoogle}
        className="w-full rounded-xl border px-4 py-3"
      >
        Continue with Google
      </button>

      <div className="text-center text-sm opacity-60">or</div>

      <form onSubmit={loginEmail} className="space-y-3">
        <input
          type="email"
          placeholder="Email"
          className="w-full border rounded-xl px-3 py-2"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          autoComplete="email"
        />
        <input
          type="password"
          placeholder="Password"
          className="w-full border rounded-xl px-3 py-2"
          value={pass}
          onChange={(e) => setPass(e.target.value)}
          required
          autoComplete="current-password"
        />
        <button className="w-full rounded-xl bg-black text-white px-4 py-3">
          Sign in with Email
        </button>
      </form>

      {error && <p className="text-red-600 text-sm">{error}</p>}
    </main>
  );
}
EOF

# --- app/(onboarding)/onboarding/page.tsx ---
cat > 'app/(onboarding)/onboarding/page.tsx' <<'EOF'
"use client";

import { useEffect, useState } from "react";
import { auth } from "@/lib/firebase-client";
import { onAuthStateChanged } from "firebase/auth";
import { useRouter } from "next/navigation";

export default function OnboardingPage() {
  const router = useRouter();
  const [role, setRole] = useState("staff");
  const [orgId, setOrgId] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        router.replace("/login");
        return;
      }
      setLoading(false);
    });
    return () => unsub();
  }, [router]);

  const complete = async (e: React.FormEvent) => {
    e.preventDefault();
    const user = auth.currentUser;
    if (!user) { router.replace("/login"); return; }
    const idToken = await user.getIdToken();

    const r = await fetch("/api/onboarding", {
      method: "POST",
      headers: { authorization: `Bearer ${idToken}` },
      body: JSON.stringify({ role, orgId }),
    });
    if (!r.ok) {
      alert("Failed to save onboarding.");
      return;
    }
    router.replace("/dashboard");
  };

  if (loading) return null;

  return (
    <main className="max-w-md mx-auto p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Finish onboarding</h1>
      <form onSubmit={complete} className="space-y-3">
        <input
          type="text"
          placeholder="Organization ID"
          className="w-full border rounded-xl px-3 py-2"
          value={orgId}
          onChange={(e) => setOrgId(e.target.value)}
          required
        />
        <select
          className="w-full border rounded-xl px-3 py-2"
          value={role}
          onChange={(e) => setRole(e.target.value)}
        >
          <option value="staff">Staff</option>
          <option value="manager">Manager</option>
          <option value="admin">Admin</option>
        </select>
        <button className="w-full rounded-xl bg-black text-white px-4 py-3">
          Complete
        </button>
      </form>
    </main>
  );
}
EOF

# --- app/dashboard/page.tsx ---
cat > app/dashboard/page.tsx <<'EOF'
export default function DashboardPage() {
  return (
    <main className="max-w-3xl mx-auto p-6 space-y-4">
      <h1 className="text-2xl font-semibold">Dashboard</h1>
      <p>Welcome. If you can see this, onboarding is complete.</p>
    </main>
  );
}
EOF

# --- app/api/session/route.ts ---
cat > app/api/session/route.ts <<'EOF'
import { NextResponse } from "next/server";
import { adminAuth, db } from "@/lib/firebase-admin";

async function getUidFromHeaders(): Promise<string | null> {
  const { headers } = await import("next/headers");
  const hdr = headers();
  const authz = hdr.get("authorization") || "";
  const m = authz.match(/^Bearer\s+(.+)$/i);
  const idToken = m?.[1];
  if (!idToken) return null;
  try {
    const decoded = await adminAuth.verifyIdToken(idToken);
    return decoded.uid;
  } catch {
    return null;
  }
}

export async function GET() {
  const uid = await getUidFromHeaders();
  if (!uid) {
    return NextResponse.json({ signedIn: false, onboardingComplete: false });
  }
  const userDoc = await db.collection("users").doc(uid).get();
  const onboardingComplete = userDoc.exists && userDoc.get("onboardingComplete") === true;
  return NextResponse.json({ signedIn: true, onboardingComplete });
}
EOF

# --- app/api/onboarding/route.ts ---
cat > app/api/onboarding/route.ts <<'EOF'
import { NextResponse } from "next/server";
import { adminAuth, db } from "@/lib/firebase-admin";

async function getUidFromRequest(req: Request): Promise<string | null> {
  const authz = req.headers.get("authorization") || "";
  const m = authz.match(/^Bearer\s+(.+)$/i);
  const idToken = m?.[1];
  if (!idToken) return null;
  try {
    const decoded = await adminAuth.verifyIdToken(idToken);
    return decoded.uid;
  } catch {
    return null;
  }
}

export async function POST(req: Request) {
  const uid = await getUidFromRequest(req);
  if (!uid) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { role, orgId } = await req.json();

  await db.collection("users").doc(uid).set(
    {
      onboardingComplete: true,
      role: role || "staff",
      orgId: orgId || null,
      updatedAt: new Date(),
    },
    { merge: true }
  );

  return NextResponse.json({ ok: true });
}
EOF

# --- middleware.ts ---
cat > middleware.ts <<'EOF'
import { NextRequest, NextResponse } from "next/server";

// Paths that don’t require auth
const PUBLIC_PATHS = ["/login", "/_next", "/favicon.ico", "/api/session"];

export async function middleware(req: NextRequest) {
  const url = req.nextUrl;
  const pathname = url.pathname;

  if (PUBLIC_PATHS.some((p) => pathname.startsWith(p))) {
    return NextResponse.next();
  }
  if (pathname.startsWith("/onboarding")) {
    return NextResponse.next();
  }

  const authz = req.headers.get("authorization") || "";
  const hasBearer = /^Bearer\s+.+$/i.test(authz);

  if (!hasBearer) {
    const login = new URL("/login", req.url);
    login.searchParams.set("next", pathname);
    return NextResponse.redirect(login);
  }

  try {
    const sessionUrl = new URL("/api/session", req.url);
    const r = await fetch(sessionUrl, {
      headers: { authorization: authz },
    });
    const data = await r.json();

    if (!data?.signedIn) {
      const login = new URL("/login", req.url);
      login.searchParams.set("next", pathname);
      return NextResponse.redirect(login);
    }
    if (!data?.onboardingComplete && !pathname.startsWith("/onboarding")) {
      return NextResponse.redirect(new URL("/onboarding", req.url));
    }
  } catch {
    const login = new URL("/login", req.url);
    login.searchParams.set("next", pathname);
    return NextResponse.redirect(login);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next|favicon.ico).*)"],
};
EOF

# --- app/layout.tsx ---
cat > app/layout.tsx <<'EOF'
import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "App",
  description: "Auth + Onboarding gate",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
EOF

# --- tsconfig.json alias patch ---
if [ -f tsconfig.json ]; then
  node - <<'NODE'
const fs=require('fs');
const p='tsconfig.json';
const j=JSON.parse(fs.readFileSync(p,'utf8'));
j.compilerOptions ??= {};
j.compilerOptions.baseUrl ??= ".";
j.compilerOptions.paths ??= {};
j.compilerOptions.paths["@/*"] ??= ["./*"];
fs.writeFileSync(p, JSON.stringify(j, null, 2));
console.log("Patched tsconfig.json with baseUrl and @/* path.");
NODE
fi

echo "Scaffold applied.
Next:
  1) cp .env.local.example .env.local && edit values
  2) ./scripts/load-firebase-admin.sh new-key.json .env.local
  3) Enable Google + Email/Password in Firebase Console → Authentication
  4) npm run dev"
