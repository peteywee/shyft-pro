import { NextResponse } from "next/server";

export async function POST() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set("sid", { value: "", path: "/", maxAge: 0 } as any);
  return res;
}
