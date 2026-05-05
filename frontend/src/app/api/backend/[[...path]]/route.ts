import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const UPSTREAM_BASE =
  process.env.TOASTER_API_PROXY_TARGET ?? "http://127.0.0.1:3001";

const HOP_BY_HOP = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailers",
  "transfer-encoding",
  "upgrade",
]);

function buildUpstreamUrl(request: NextRequest, segments: string[] | undefined) {
  const segs = segments ?? [];
  const u = new URL(UPSTREAM_BASE);
  u.pathname = segs.length ? `/${segs.join("/")}` : "/";
  u.search = request.nextUrl.search;
  return u;
}

function buildProxyRequestHeaders(request: NextRequest): Headers {
  const out = new Headers();
  request.headers.forEach((value, key) => {
    if (HOP_BY_HOP.has(key.toLowerCase())) return;
    if (key.toLowerCase() === "host") return;
    out.append(key, value);
  });
  const host = request.headers.get("host");
  if (host) {
    out.set("x-forwarded-host", host);
  }
  return out;
}

function appendSetCookieHeaders(upstream: Response, out: NextResponse): void {
  const h = upstream.headers as Headers & { getSetCookie?: () => string[] };
  if (typeof h.getSetCookie === "function") {
    const list = h.getSetCookie();
    if (list?.length) {
      for (const cookie of list) {
        out.headers.append("Set-Cookie", cookie);
      }
      return;
    }
  }
  const single = upstream.headers.get("set-cookie");
  if (single) {
    out.headers.append("Set-Cookie", single);
  }
}

function copyUpstreamHeadersToNext(upstream: Response, out: NextResponse) {
  appendSetCookieHeaders(upstream, out);
  upstream.headers.forEach((value, key) => {
    if (key.toLowerCase() === "set-cookie") return;
    out.headers.append(key, value);
  });
}

async function proxy(
  request: NextRequest,
  segments: string[] | undefined,
): Promise<Response> {
  const url = buildUpstreamUrl(request, segments);
  const init: RequestInit = {
    method: request.method,
    headers: buildProxyRequestHeaders(request),
    redirect: "manual",
  };
  if (request.method !== "GET" && request.method !== "HEAD") {
    init.body = request.body;
    (init as { duplex?: string }).duplex = "half";
  }

  const upstream = await fetch(url, init);
  const body = await upstream.arrayBuffer();
  const res = new NextResponse(body, {
    status: upstream.status,
    statusText: upstream.statusText,
  });
  copyUpstreamHeadersToNext(upstream, res);
  return res;
}

type RouteCtx = { params: Promise<{ path?: string[] }> };

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

async function handle(request: NextRequest, ctx: RouteCtx) {
  const { path } = await ctx.params;
  return proxy(request, path);
}

export const GET = handle;
export const POST = handle;
export const PUT = handle;
export const PATCH = handle;
export const DELETE = handle;
export const HEAD = handle;
export const OPTIONS = handle;
