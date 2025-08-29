import { NextRequest, NextResponse } from "next/server";
import { db } from "../../lib/firebase-admin";

function sid(req: NextRequest) { return req.cookies.get("sid")?.value || ""; }

export async function POST(req: NextRequest) {
  const s = sid(req);
  if (!s) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  // Merge minimal flags into existing snapshot
  const snap = db.getOnboarding("-", s) || {};
  const nextSnap = {
    ...snap,
    user: { ...(snap.user || {}), verified: true },
    membership: { ...(snap.membership || {}), choice: "join", orgId: "-" },
    i9: { ...(snap.i9 || {}), section1: { completed: true } },
    w4: { submitted: true },
    banking: { added: true }
  };
  db.setOnboarding("-", s, nextSnap);

  const res = NextResponse.json({ ok: true });
  res.cookies.set("onb", "1", {
    path: "/",
    maxAge: 3600,
    secure: process.env.NODE_ENV === "production"
  } as any);
  return res;
}
