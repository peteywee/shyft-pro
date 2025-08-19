// server/src/index.ts (additions highlighted)
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { auth } from './firebase';
import { buildOrgRouter } from './routes/orgs'; // <-- add
const app = express();
app.use(express.json());
const corsOrigin = process.env.CORS_ORIGIN?.split(',').map(s => s.trim()) ?? ['http://localhost:5173'];
app.use(cors({ origin: corsOrigin, credentials: true }));
// Verify Firebase ID token middleware (attach uid + decoded to req)
async function verifyFirebaseToken(req, res, next) {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token)
        return res.status(401).json({ error: 'missing Authorization: Bearer <token>' });
    try {
        const decoded = await auth.verifyIdToken(token);
        req.uid = decoded.uid;
        req.user = decoded;
        next();
    }
    catch {
        return res.status(401).json({ error: 'invalid token' });
    }
}
app.get('/api/health', (_, res) => res.json({ ok: true }));
// === mount org routes ===
app.use('/api/orgs', buildOrgRouter(verifyFirebaseToken));
// (existing routes) /api/me, /api/export/timesheets.csv, /api/admin/assignRole ...
// ... keep the rest of your file as-is
const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`API listening on :${port}`));
