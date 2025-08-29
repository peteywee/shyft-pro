import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db-mock";
import { evaluateCompletion } from "@/lib/onboarding/state";

function getSid(req: NextRequest) { return req.cookies.get("sid")?.value || ""; }

export async function GET(req: NextRequest) {
  const sid = getSid(req);
  const sess = sid ? { userId: sid } : null; // sid is uid for Firebase or a random session for dev
  if (!sess) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const snapshot = db.getOnboarding("-", sess.userId) || {};
  const state = evaluateCompletion(snapshot);
  return NextResponse.json({ userId: sess.userId, snapshot, state });
}
