// server/src/index.ts
import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import bodyParser from 'body-parser'

// ⬇️ add these two for static hosting
import path from 'path'
import { fileURLToPath } from 'url'

import { auth, db } from './firebase'
import { verifyFirebaseToken } from './auth'
import { onboardingRouter } from './onboarding'

const app = express()
app.use(cors({ origin: process.env.CORS_ORIGIN?.split(',') || true }))
app.use(bodyParser.json({ limit: '1mb' }))

// Optional health and root (nice to have)
app.get('/', (_req, res) => res.status(200).send('auth-onboarding-api: OK'))
app.get('/healthz', (_req, res) => res.json({ ok: true, uptime: process.uptime(), ts: new Date().toISOString() }))
app.get('/api/health', (_req, res) => res.json({ ok: true, uptime: process.uptime(), ts: new Date().toISOString() }))

// whoami (+ bootstrap email into users doc if missing)
app.get('/api/me', verifyFirebaseToken, async (req: any, res) => {
  const uid = req.uid as string
  const ref = db.collection('users').doc(uid)
  const snap = await ref.get()
  let data = snap.data() || {}

  if (!data.email) {
    try {
      const userRec = await auth.getUser(uid)
      const email = (userRec.email || '').toLowerCase()
      if (email) {
        await ref.set({ email }, { merge: true })
        data.email = email
      }
    } catch { /* ignore */ }
  }

  return res.json({ uid, orgId: data.orgId, role: data.role, status: data.status })
})

/* ------------------------ STATIC HOSTING (PUT IT HERE) ------------------------ */
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Only enable if you deploy with a client build available
if (process.env.SERVE_STATIC === 'true') {
  const clientDist = path.resolve(__dirname, '../../client/dist');
  app.use(express.static(clientDist));
  // Fallback to index.html for client-side routes
  app.get('*', (_req, res) => {
    res.sendFile(path.join(clientDist, 'index.html'));
  });
}
/* ----------------------------------------------------------------------------- */

// API routers
app.use('/api', onboardingRouter(verifyFirebaseToken))

const port = Number(process.env.PORT || 8080)
app.listen(port, () => {
  console.log(`API listening on http://localhost:${port}`)
})
