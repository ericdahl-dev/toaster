import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

/** Same default as former next.config rewrite target (Rails dev server). */
const UPSTREAM_BASE =
  process.env.TOASTER_API_PROXY_TARGET ?? "http://127.0.0.1:3001";

/**
 * Proxy /api/backend/* to Rails. We must use NextResponse.rewrite(upstreamUrl) here — headers
 * added via NextResponse.next() are NOT forwarded to external destinations configured in
 * next.config rewrites, so Rails never saw X-Forwarded-Host and Set-Cookie stayed on 127.0.0.1.
 */
export function middleware(request: NextRequest) {
  const host = request.headers.get("host");
  let rest = request.nextUrl.pathname.replace(/^\/api\/backend\/?/, "");
  const pathForUrl =
    rest === "" ? "/" : rest.startsWith("/") ? rest : `/${rest}`;
  const dest = new URL(`${pathForUrl}${request.nextUrl.search}`, UPSTREAM_BASE);

  const requestHeaders = new Headers(request.headers);
  if (host) {
    requestHeaders.set("x-forwarded-host", host);
  }

  return NextResponse.rewrite(dest, {
    request: { headers: requestHeaders },
  });
}

export const config = {
  matcher: "/api/backend/:path*",
};
