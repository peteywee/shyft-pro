import { NextRequest, NextResponse } from "next/server";
import { adminAuth } from "@/server/firebaseAdmin";
import { db } from "@/lib/db-mock";

export async function POST(req: NextRequest) {
  const { idToken } = await req.json();
  if (!idToken) return NextResponse.json({ error: "idToken required" }, { status: 400 });

  const decoded = await adminAuth().verifyIdToken(idToken, true);
  const uid = decoded.uid;

  // Persist a minimal onboarding snapshot if none exists
  const existing = db.getOnboarding("-", uid);
  if (!existing) {
    db.setOnboarding("-", uid, {
      user: { emailOrPhone: decoded.email || "", authMethod: "firebase", verified: !!decoded.email_verified, role: "staff" },
      membership: { choice: null, orgId: "-", role: "staff" }
    });
  }

  const res = NextResponse.json({ ok: true, uid });
  res.cookies.set("sid", {
    value: uid,               // map sid to uid for simplicity
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 14,
    secure: true
  } as any);
  return res;
}
