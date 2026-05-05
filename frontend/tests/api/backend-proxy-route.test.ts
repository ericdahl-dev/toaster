/**
 * The generic `/api/backend` proxy and `serverFetchBackend` are how the Next app keeps
 * session cookies on the same origin as the page. Credential-bearing browser `fetch` and
 * RSC server checks should go through this proxy, not a direct host:port to Puma, or
 * Set-Cookie scoping and `/auth/me` can disagree (see root `AGENTS.md`).
 */
import { NextRequest } from 'next/server';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

describe('api/backend/[...path] proxy route', () => {
  const envSnapshot = { ...process.env };
  let GET: (req: NextRequest, ctx: { params: Promise<{ path?: string[] }> }) => Promise<Response>;

  beforeEach(async () => {
    vi.restoreAllMocks();
    process.env = { ...envSnapshot };
    vi.stubEnv('TOASTER_API_PROXY_TARGET', 'http://upstream.test');
    vi.resetModules();
    ({ GET } = await import('@/app/api/backend/[[...path]]/route'));
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    process.env = { ...envSnapshot };
  });

  it('forwards GET to upstream with path, query, and cookies', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response('ok', { status: 200, statusText: 'OK' }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const req = new NextRequest('http://localhost:3000/api/backend/v1/things?q=1', {
      method: 'GET',
      headers: {
        host: 'localhost:3000',
        cookie: 'session=abc',
      },
    });

    const res = await GET(req, { params: Promise.resolve({ path: ['v1', 'things'] }) });

    expect(res.status).toBe(200);
    expect(await res.text()).toBe('ok');

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [URL, RequestInit];
    expect(url.toString()).toBe('http://upstream.test/v1/things?q=1');
    expect(init.method).toBe('GET');
    expect(init.redirect).toBe('manual');
    const outHeaders = new Headers(init.headers as HeadersInit);
    expect(outHeaders.get('cookie')).toBe('session=abc');
    expect(outHeaders.get('x-forwarded-host')).toBe('localhost:3000');
  });

  it('omits hop-by-hop headers and host from upstream request', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response('', { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);

    const req = new NextRequest('http://localhost:3000/api/backend/x', {
      method: 'GET',
      headers: {
        host: 'localhost:3000',
        connection: 'keep-alive',
        'transfer-encoding': 'chunked',
      },
    });

    await GET(req, { params: Promise.resolve({ path: ['x'] }) });

    const [, init] = fetchMock.mock.calls[0] as [URL, RequestInit];
    const outHeaders = new Headers(init.headers as HeadersInit);
    expect(outHeaders.get('connection')).toBeNull();
    expect(outHeaders.get('transfer-encoding')).toBeNull();
    expect(outHeaders.get('host')).toBeNull();
  });

  it('passes through upstream error status and body', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(new Response('nope', { status: 401, statusText: 'Unauthorized' })),
    );

    const req = new NextRequest('http://localhost:3000/api/backend/auth/me', { method: 'GET' });
    const res = await GET(req, { params: Promise.resolve({ path: ['auth', 'me'] }) });

    expect(res.status).toBe(401);
    expect(res.statusText).toBe('Unauthorized');
    expect(await res.text()).toBe('nope');
  });

  it('appends Set-Cookie from upstream onto the response', async () => {
    const upstream = new Response('ok', { status: 200 });
    const h = upstream.headers as Headers & { getSetCookie?: () => string[] };
    h.getSetCookie = () => ['a=1; Path=/', 'b=2; Path=/'];

    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(upstream));

    const req = new NextRequest('http://localhost:3000/api/backend/login', { method: 'POST' });
    const res = await GET(req, { params: Promise.resolve({ path: ['login'] }) });

    const setCookies = res.headers.getSetCookie?.() ?? [];
    expect(setCookies).toContain('a=1; Path=/');
    expect(setCookies).toContain('b=2; Path=/');
  });
});
