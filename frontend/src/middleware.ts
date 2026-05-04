import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

/**
 * Next rewrites /api/backend/* to Rails on 127.0.0.1:3001. Without X-Forwarded-Host, Rails
 * issues session cookies for 127.0.0.1 while the user is on localhost — cookies won't match.
 */
export function middleware(request: NextRequest) {
  const host = request.headers.get("host");
  if (!host) {
    return NextResponse.next();
  }

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-forwarded-host", host);
  return NextResponse.next({
    request: { headers: requestHeaders },
  });
}

export const config = {
  matcher: "/api/backend/:path*",
};
