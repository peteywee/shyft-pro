// server/src/routes/orgs.ts
import { Router } from 'express';
import { z } from 'zod';
import { db } from '../firebase';
const CreateOrgBody = z.object({
    name: z.string().min(2).max(80),
    invites: z
        .object({
        managers: z.array(z.string().email()).optional(),
        staff: z.array(z.string().email()).optional(),
    })
        .optional(),
});
const JoinOrgBody = z.object({
    orgId: z.string().min(6),
});
export function buildOrgRouter(verifyFirebaseToken) {
    const r = Router();
    // POST /api/orgs — create an org; caller becomes admin/owner
    r.post('/', verifyFirebaseToken, async (req, res) => {
        try {
            const { uid, user } = req;
            const emailFromToken = user?.email || null;
            const body = CreateOrgBody.parse(req.body);
            const orgRef = db.collection('orgs').doc();
            const membersRef = orgRef.collection('meta').doc('members');
            const userRef = db.collection('users').doc(uid);
            await db.runTransaction(async (tx) => {
                const now = new Date();
                tx.set(orgRef, {
                    name: body.name,
                    createdBy: uid,
                    createdAt: now,
                });
                const owners = emailFromToken ? [emailFromToken] : [];
                tx.set(membersRef, {
                    owners,
                    managers: body.invites?.managers ?? [],
                    staff: body.invites?.staff ?? [],
                    updatedAt: now,
                });
                tx.set(userRef, {
                    orgId: orgRef.id,
                    role: 'admin',
                    email: emailFromToken || null,
                    display_name: user?.name || null,
                    updatedAt: now,
                    createdAt: now,
                }, { merge: true });
            });
            return res.status(201).json({ orgId: orgRef.id, name: body.name });
        }
        catch (e) {
            if (e instanceof z.ZodError) {
                return res.status(400).json({ error: 'invalid_body', details: e.issues });
            }
            console.error('create org error', e);
            return res.status(500).json({ error: 'internal' });
        }
    });
    // POST /api/orgs/join — join an org; role determined by email in invite lists
    r.post('/join', verifyFirebaseToken, async (req, res) => {
        try {
            const { uid, user } = req;
            const email = user?.email;
            if (!email)
                return res.status(400).json({ error: 'email_required' });
            const { orgId } = JoinOrgBody.parse(req.body);
            const orgRef = db.collection('orgs').doc(orgId);
            const membersRef = orgRef.collection('meta').doc('members');
            const userRef = db.collection('users').doc(uid);
            const [orgSnap, memSnap] = await Promise.all([orgRef.get(), membersRef.get()]);
            if (!orgSnap.exists)
                return res.status(404).json({ error: 'org_not_found' });
            const members = (memSnap.exists ? memSnap.data() : null);
            if (!members)
                return res.status(403).json({ error: 'no_membership_config' });
            const lower = (s) => s.trim().toLowerCase();
            const e = lower(email);
            const inOwners = (members.owners ?? []).map(lower).includes(e);
            const inManagers = (members.managers ?? []).map(lower).includes(e);
            const inStaff = (members.staff ?? []).map(lower).includes(e);
            let role = null;
            if (inOwners)
                role = 'admin';
            else if (inManagers)
                role = 'manager';
            else if (inStaff)
                role = 'staff';
            if (!role)
                return res.status(403).json({ error: 'not_invited' });
            await userRef.set({
                orgId,
                role,
                email,
                updatedAt: new Date(),
            }, { merge: true });
            return res.json({ orgId, role });
        }
        catch (e) {
            if (e instanceof z.ZodError) {
                return res.status(400).json({ error: 'invalid_body', details: e.issues });
            }
            console.error('join org error', e);
            return res.status(500).json({ error: 'internal' });
        }
    });
    // GET /api/orgs/me — summarize my org + role
    r.get('/me', verifyFirebaseToken, async (req, res) => {
        try {
            const { uid } = req;
            const meSnap = await db.collection('users').doc(uid).get();
            if (!meSnap.exists)
                return res.status(404).json({ error: 'user_not_initialized' });
            const me = meSnap.data();
            const { orgId, role } = me || {};
            if (!orgId)
                return res.status(404).json({ error: 'no_org' });
            const orgSnap = await db.collection('orgs').doc(orgId).get();
            const name = orgSnap.get('name') || null;
            return res.json({ orgId, name, role });
        }
        catch (e) {
            console.error('me org error', e);
            return res.status(500).json({ error: 'internal' });
        }
    });
    return r;
}
