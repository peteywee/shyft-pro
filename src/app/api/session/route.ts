import { NextRequest, NextResponse } from "next/server";
import { adminAuth } from "@/lib/firebase-admin";
import { db } from "@/lib/firebase-admin";
import { isAllowed } from "@/lib/allowlist";
import crypto from "node:crypto";
import { evaluateCompletion } from "@/lib/onboarding/state";

function sidFrom(req: NextRequest) { return req.cookies.get("sid")?.value || ""; }

export async function GET(req: NextRequest) {
  const sid = sidFrom(req);
  if (!sid) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const snapshot = db.getOnboarding("-", sid) || {};
  const state = evaluateCompletion(snapshot);
  return NextResponse.json({ userId: sid, snapshot, state });
}

/**
 * POST login:
 *  - If body has { idToken }, verify Firebase ID token -> set sid=uid (real Google sign-in)
 *  - Else if body has { email }, dev allowlist email flow -> sid=random (legacy/dev)
 */
export async function POST(req: NextRequest) {
  const { idToken, email, newAccount } = await req.json();

  // Prefer Firebase ID token when supplied
  if (idToken) {
    const decoded = await adminAuth().verifyIdToken(idToken, true);
    const uid = decoded.uid;

    // Seed minimal snapshot if missing
    const existing = db.getOnboarding("-", uid);
    if (!existing) {
      db.setOnboarding("-", uid, {
        user: { emailOrPhone: decoded.email || "", authMethod: "firebase", verified: !!decoded.email_verified, role: "staff" },
        membership: { choice: newAccount ? null : "join", orgId: "-", role: "staff" }
      });
    }

    const res = NextResponse.json({ ok: true, userId: uid, method: "firebase" });
    res.cookies.set("sid", { value: uid, httpOnly: true, sameSite: "lax", path: "/", maxAge: 60*60*24*14, secure: true } as any);
    return res;
  }

  // Fallback: dev email flow with allowlist
  if (email) {
    if (!isAllowed(email)) {
      return NextResponse.json({ error: "not allowed" }, { status: 403 });
    }
    const userId = crypto.createHash("sha256").update(String(email)).digest("hex").slice(0, 16);
    const sid = crypto.randomBytes(12).toString("hex");

    db.putSession(sid, { userId });
    db.setOnboarding("-", userId, {
      user: { emailOrPhone: email, authMethod: "password", verified: true, role: "staff" },
      membership: { choice: newAccount ? null : "join", orgId: "-", role: "staff" }
    });

    const res = NextResponse.json({ ok: true, userId, method: "dev-email" });
    res.cookies.set("sid", { value: sid, httpOnly: true, sameSite: "lax", path: "/", maxAge: 60*60*24*14, secure: true } as any);
    return res;
  }

  return NextResponse.json({ error: "idToken or email required" }, { status: 400 });
}

export async function DELETE() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set("sid", { value: "", path: "/", maxAge: 0 } as any);
  return res;
}
