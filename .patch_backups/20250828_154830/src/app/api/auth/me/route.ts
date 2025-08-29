import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db-mock";

function getSid(req: NextRequest) { return req.cookies.get("sid")?.value || ""; }

export async function GET(req: NextRequest) {
  const sid = getSid(req);
  const sess = db.getSession(sid);
  if (!sess) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const snapshot = db.getOnboarding("-", sess.userId) || {};
  return NextResponse.json({ userId: sess.userId, snapshot });
}
