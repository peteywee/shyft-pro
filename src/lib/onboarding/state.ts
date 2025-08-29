// src/lib/onboarding/state.ts
import crypto from "node:crypto";

export type CompletionState = {
  complete: boolean;
  nextStep?: string;
  etag: string;
  updatedAt: number;
};

// In-memory cache (replace with Redis for production)
const memoryKV = new Map<string, CompletionState>();

export function cacheKey(userId: string, orgId: string) {
  return `onb:${orgId || "-"}:${userId || "-"}`;
}

export function computeEtag(snapshot: unknown): string {
  const json = JSON.stringify(snapshot || {});
  return crypto.createHash("sha1").update(json).digest("hex");
}

export function evaluateCompletion(snapshot: any): CompletionState {
  // Minimal, opinionated rules – adjust as your schema evolves.
  // Required gates for first-time flow:
  // 1) user.verified
  // 2) membership.choice in {"create","join"}
  // 3) if join -> membership.orgId present
  // 4) i9.section1.completed === true
  // 5) w4.submitted === true
  // 6) banking.added === true
  const okUser = !!snapshot?.user?.verified;
  const choice = snapshot?.membership?.choice;
  const okChoice = choice === "create" || choice === "join";
  const okOrg = choice === "create" ? true : !!snapshot?.membership?.orgId;
  const okI9 = !!snapshot?.i9?.section1?.completed;
  const okW4 = !!snapshot?.w4?.submitted;
  const okBank = !!snapshot?.banking?.added;

  const complete = Boolean(okUser && okChoice && okOrg && okI9 && okW4 && okBank);

  // Decide next step if not complete
  let nextStep: string | undefined;
  if (!okUser) nextStep = "verify-contact";
  else if (!okChoice) nextStep = "org-choice";
  else if (!okOrg) nextStep = "join-organization";
  else if (!okI9) nextStep = "i9-section1";
  else if (!okW4) nextStep = "w4";
  else if (!okBank) nextStep = "banking";

  return {
    complete,
    nextStep,
    etag: computeEtag(snapshot),
    updatedAt: Date.now()
  };
}

export function getCachedState(userId: string, orgId: string): CompletionState | undefined {
  return memoryKV.get(cacheKey(userId, orgId));
}

export function setCachedState(userId: string, orgId: string, state: CompletionState) {
  memoryKV.set(cacheKey(userId, orgId), { ...state, updatedAt: Date.now() });
}
