// src/lib/db-mock.ts
// Super-simple in-memory stores for dev only. Replace with Firestore later.

type Session = { userId: string };
type Snapshot = Record<string, any>;

const sessions = new Map<string, Session>();
// Keyed by orgId (we use "-" for single-tenant dev) then userId
const onboarding = new Map<string, Map<string, Snapshot>>();

function getOrg(orgId: string) {
  const k = orgId || "-";
  if (!onboarding.has(k)) onboarding.set(k, new Map());
  return onboarding.get(k)!;
}

export function putSession(sid: string, session: Session) {
  sessions.set(sid, session);
}
export function getSession(sid: string) {
  return sessions.get(sid) || null;
}

export function setOnboarding(orgId: string, userId: string, snapshot: Snapshot) {
  getOrg(orgId).set(userId, snapshot);
}
export function getOnboarding(orgId: string, userId: string): Snapshot | null {
  return getOrg(orgId).get(userId) || null;
}

export const db = { putSession, getSession, setOnboarding, getOnboarding };
export default db;
