import { NextResponse } from "next/server";
import { adminAuth, db } from "@/lib/firebase-admin";

async function getUidFromRequest(req: Request): Promise<string | null> {
  const authz = req.headers.get("authorization") || "";
  const m = authz.match(/^Bearer\s+(.+)$/i);
  const idToken = m?.[1];
  if (!idToken) return null;
  try {
    const decoded = await adminAuth.verifyIdToken(idToken);
    return decoded.uid;
  } catch {
    return null;
  }
}

export async function POST(req: Request) {
  const uid = await getUidFromRequest(req);
  if (!uid) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { role, orgId } = await req.json();

  await db.collection("users").doc(uid).set(
    {
      onboardingComplete: true,
      role: role || "staff",
      orgId: orgId || null,
      updatedAt: new Date(),
    },
    { merge: true }
  );

  return NextResponse.json({ ok: true });
}
