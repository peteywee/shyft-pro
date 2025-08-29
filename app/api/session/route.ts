import { NextResponse } from "next/server";
import { adminAuth, db } from "../../lib/firebase-admin";
import { headers, cookies } from "next/headers";

function bearerFromCookie(): string | null {
  const raw = cookies().get("__session")?.value || "";
  const m = raw.match(/^Bearer\s+(.+)$/i);
  return m?.[1] || null;
}

async function uidFromRequest(): Promise<string | null> {
  const hdr = headers();
  const authz = hdr.get("authorization") || "";
  const m = authz.match(/^Bearer\s+(.+)$/i);
  const idToken = m?.[1] || bearerFromCookie();
  if (!idToken) return null;
  try {
    const decoded = await adminAuth.verifyIdToken(idToken);
    return decoded.uid;
  } catch {
    return null;
  }
}

export async function GET() {
  const uid = await uidFromRequest();
  if (!uid) return NextResponse.json({ signedIn: false, onboardingComplete: false });

  const snap = await db.collection("users").doc(uid).get();
  const onboardingComplete = snap.exists && snap.get("onboardingComplete") === true;
  return NextResponse.json({ signedIn: true, onboardingComplete });
}
