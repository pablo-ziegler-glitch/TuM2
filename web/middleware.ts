import { NextRequest, NextResponse } from "next/server";

/**
 * Middleware that protects /admin/* routes.
 * Verifies the Firebase Auth session cookie and redirects to /admin/login if invalid.
 *
 * Note: Token verification with Firebase Admin SDK must happen in Route Handlers
 * or Server Actions (not in Edge middleware) due to Node.js dependencies.
 * This middleware provides the initial route guard; full token validation
 * happens in admin/layout.tsx server component.
 */
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Protect admin routes
  if (pathname.startsWith("/admin")) {
    const sessionCookie = request.cookies.get("__session")?.value;

    if (!sessionCookie) {
      const loginUrl = new URL("/admin/login", request.url);
      loginUrl.searchParams.set("redirect", pathname);
      return NextResponse.redirect(loginUrl);
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*"],
};
