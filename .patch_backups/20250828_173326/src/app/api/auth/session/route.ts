import { NextRequest, NextResponse } from "next/server";
import crypto from "node:crypto";
import { db } from "@/lib/db-mock";
import { isAllowed } from "@/lib/allowlist";

/**
 * DEV-ONLY session creation
 */
export async function POST(req: NextRequest) {
  const { email, newAccount } = await req.json();
  if (!email) return NextResponse.json({ error: "email required" }, { status: 400 });
  if (!isAllowed(email)) return NextResponse.json({ error: "not allowed" }, { status: 403 });

  const userId = crypto.createHash("sha256").update(String(email)).digest("hex").slice(0, 16);
  const sid = crypto.randomBytes(12).toString("hex");

  db.putSession(sid, { userId });

  // Seed minimal onboarding snapshot baseline for this user
  db.setOnboarding("-", userId, {
    user: { emailOrPhone: email, authMethod: "password", verified: true, role: "staff" },
    membership: { choice: newAccount ? null : "join", orgId: "-", role: "staff" }
  });

  const res = NextResponse.json({ ok: true, userId });
  res.cookies.set("sid", {
    value: sid,
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 14, // 14 days
    secure: true
  } as any);
  return res;
}
