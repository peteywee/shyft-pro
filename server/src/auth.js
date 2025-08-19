import { auth } from './firebase';
export async function verifyFirebaseToken(req, res, next) {
    const h = req.header('authorization') || req.header('Authorization') || '';
    const m = h.match(/^Bearer\s+(.+)$/i);
    if (!m)
        return res.status(401).json({ error: 'Missing Bearer token' });
    try {
        const decoded = await auth.verifyIdToken(m[1]);
        req.uid = decoded.uid;
        return next();
    }
    catch (e) {
        return res.status(401).json({ error: 'Invalid token' });
    }
}
