// server/src/onboarding.ts
import express from 'express'
import crypto from 'crypto'
import { db } from './firebase.js'

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
