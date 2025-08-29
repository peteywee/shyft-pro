import { NextRequest, NextResponse } from "next/server";

const PUBLIC = ["/login", "/_next", "/favicon.ico", "/api/auth/session"];

export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  if (PUBLIC.some((p) => pathname.startsWith(p))) return NextResponse.next();
  if (pathname.startsWith("/onboarding")) return NextResponse.next();

  try {
    const r = await fetch(new URL("/api/session", req.url), {
      headers: { cookie: req.headers.get("cookie") || "" },
    });
    const s = await r.json();

    if (!s?.signedIn) {
      const to = new URL("/login", req.url);
      to.searchParams.set("next", pathname);
      return NextResponse.redirect(to);
    }
    if (!s?.onboardingComplete && !pathname.startsWith("/onboarding")) {
      return NextResponse.redirect(new URL("/onboarding", req.url));
    }
  } catch {
    const to = new URL("/login", req.url);
    to.searchParams.set("next", pathname);
    return NextResponse.redirect(to);
  }
  return NextResponse.next();
}

export const config = { matcher: ["/((?!_next|favicon.ico).*)"] };
