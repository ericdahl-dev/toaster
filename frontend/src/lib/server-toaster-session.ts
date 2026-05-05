import { cookies, headers } from 'next/headers';

/**
 * Fetch the Rails API through the same-origin `/api/backend` proxy (Route Handler). RSC code
 * must not call `serverRailsBaseUrl()` for session checks: that hits Puma directly without
 * X-Forwarded-Host, so Set-Cookie host scoping and session lookup disagree with the browser.
 */
export async function serverFetchBackend(
  path: string,
  init?: RequestInit,
): Promise<Response> {
  const jar = await cookies();
  const h = await headers();
  const proto = h.get('x-forwarded-proto') ?? 'http';
  const hostRaw = h.get('x-forwarded-host') ?? h.get('host') ?? 'localhost:3000';
  const host = hostRaw.split(',')[0].trim();
  const origin = `${proto}://${host}`;
  const base = '/api/backend';
  const p = path.startsWith('/') ? path : `/${path}`;
  const rawCookie = (h.get('cookie') ?? '').trim();
  const fromJar = jar.getAll().map((c) => `${c.name}=${c.value}`).join('; ');
  const cookieHeader = rawCookie || fromJar;

  const merged = new Headers(init?.headers ?? undefined);
  if (cookieHeader) {
    merged.set('cookie', cookieHeader);
  }

  return fetch(`${origin}${base}${p}`, {
    ...init,
    cache: 'no-store',
    headers: merged,
  });
}
