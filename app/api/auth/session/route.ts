import { NextResponse } from "next/server";
import { adminAuth } from "@/lib/firebase-admin";

/** POST { idToken } -> sets httpOnly __session cookie */
export async function POST(req: Request) {
  const { idToken } = await req.json().catch(() => ({}));
  if (!idToken) return NextResponse.json({ error: "Missing idToken" }, { status: 400 });

  try {
    const decoded = await adminAuth.verifyIdToken(idToken);
    const res = NextResponse.json({ ok: true, uid: decoded.uid });
    res.cookies.set({
      name: "__session",
      value: `Bearer ${idToken}`,
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge: 60 * 60 * 8, // 8h
    });
    return res;
  } catch (e: any) {
    return NextResponse.json({ error: e?.message || "Invalid token" }, { status: 401 });
  }
}

/** DELETE -> clears cookie */
export async function DELETE() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set({
    name: "__session",
    value: "",
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 0,
  });
  return res;
}
