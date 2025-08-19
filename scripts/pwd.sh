#!/usr/bin/env bash
set -euo pipefail

# ensure we run from repo root (contains package.json)
if [ ! -f package.json ]; then
  echo "Run from repo root (package.json not found)"; exit 1
fi

mkdir -p apps/api apps/web packages/shared

# --- API scaffold (idempotent) ---
if [ ! -f apps/api/package.json ]; then
  pushd apps/api >/dev/null
  npm init -y >/dev/null
  npm pkg set name="@ryne/api"
  npm i hono zod
  npm i -D wrangler typescript @cloudflare/workers-types esbuild
  mkdir -p src

  cat > src/index.ts <<'TS'
import { Hono } from 'hono';
import { z } from 'zod';

const app = new Hono();

// CORS for dev
app.use('*', async (c, next) => {
  const h = c.res.headers;
  h.set('Access-Control-Allow-Origin', '*');
  h.set('Access-Control-Allow-Headers', 'content-type, authorization');
  h.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  if (c.req.method === 'OPTIONS') return c.text('', 204);
  return next();
});

// basic timing/logging
app.use('*', async (c, next) => {
  const start = Date.now();
  await next();
  const ms = Date.now() - start;
  console.log(JSON.stringify({ path: c.req.path, status: c.res.status, ms }));
});

app.get('/health', c => c.json({ status: 'ok' }));

const PunchBody = z.object({
  type: z.enum(['IN','OUT']),
  siteId: z.string().optional(),
  tsDevice: z.string().optional(),
  idempotencyKey: z.string().optional()
});

app.post('/punch', async c => {
  const body = await c.req.json().catch(() => ({}));
  const parsed = PunchBody.safeParse(body);
  if (!parsed.success) return c.json({ error: 'Bad input' }, 400);
  return c.json({ id: 'stub', ts_server: new Date().toISOString() }, 201);
});

export default app;
TS

  cat > wrangler.toml <<'TOML'
name = "time-mvp-api"
main = "src/index.ts"
compatibility_date = "2024-10-01"
TOML

  cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "types": ["@cloudflare/workers-types"]
  },
  "include": ["src"]
}
JSON

  npm pkg set scripts.build="esbuild src/index.ts --bundle --format=esm --outfile=dist/index.js"
  npm pkg set scripts.dev="wrangler dev --local"
  popd >/dev/null
fi

# --- Web scaffold (idempotent) ---
if [ ! -f apps/web/package.json ]; then
  npm create vite@latest apps/web -- --template react-ts
  pushd apps/web >/dev/null
  npm pkg set name="@ryne/web"
  npm i simplewebauthn-browser zod

  cat > src/Punch.tsx <<'TSX'
import { useState } from 'react';

export default function Punch() {
  const [busy, setBusy] = useState(false);
  const [last, setLast] = useState<'IN'|'OUT'|null>(null);

  const go = async () => {
    if (busy) return;
    setBusy(true);
    try {
      const type = last === 'IN' ? 'OUT' : 'IN';
      const res = await fetch('/api/punch', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ type })
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.error || 'Error');
      setLast(type);
      alert(`Recorded ${type} @ ${json.ts_server}`);
    } catch (e:any) {
      alert(e.message || 'Error');
    } finally {
      setBusy(false);
    }
  };

  return (
    <button onClick={go} disabled={busy} style={{ fontSize: 24, padding: 24 }}>
      {busy ? 'Working…' : (last === 'IN' ? 'Clock Out' : 'Clock In')}
    </button>
  );
}
TSX

  cat > src/App.tsx <<'TSX'
import Punch from './Punch';
export default function App() {
  return (
    <div style={{ display:'grid', placeItems:'center', height:'100vh' }}>
      <Punch />
    </div>
  );
}
TSX

  cat > vite.config.ts <<'TS'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8787',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api/, '')
      }
    }
  }
})
TS

  popd >/dev/null
fi

# --- Shared package placeholder (idempotent) ---
if [ ! -f packages/shared/package.json ]; then
  mkdir -p packages/shared
  pushd packages/shared >/dev/null
  npm init -y >/dev/null
  npm pkg set name="@ryne/shared"
  echo "// shared utils later" > index.js
  popd >/dev/null
fi

echo "Bootstrap complete."
