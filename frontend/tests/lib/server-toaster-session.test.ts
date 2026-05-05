/**
 * Server-side Rails access must use `serverFetchBackend` (same-origin `/api/backend`) so
 * cookies and forwarded host match the browser session (see root `AGENTS.md`).
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const cookiesMock = vi.fn();
const headersMock = vi.fn();

vi.mock('next/headers', () => ({
  cookies: () => cookiesMock(),
  headers: () => headersMock(),
}));

describe('server-toaster-session', () => {
  const envSnapshot = { ...process.env };

  beforeEach(async () => {
    vi.resetModules();
    process.env = { ...envSnapshot };
    cookiesMock.mockReset();
    headersMock.mockReset();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    process.env = { ...envSnapshot };
  });

  it('builds same-origin /api/backend URL from forwarded proto/host', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response());
    vi.stubGlobal('fetch', fetchMock);

    headersMock.mockResolvedValue({
      get: (name: string) => {
        if (name === 'x-forwarded-proto') return 'https';
        if (name === 'x-forwarded-host') return 'app.example.com';
        if (name === 'cookie') return '';
        return null;
      },
    });
    cookiesMock.mockResolvedValue({
      getAll: () => [],
    });

    const { serverFetchBackend } = await import('@/lib/server-toaster-session');
    await serverFetchBackend('/users/me');

    expect(fetchMock).toHaveBeenCalledWith(
      'https://app.example.com/api/backend/users/me',
      expect.objectContaining({
        cache: 'no-store',
      }),
    );
  });

  it('prefers Cookie header over jar when both could apply', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response());
    vi.stubGlobal('fetch', fetchMock);

    headersMock.mockResolvedValue({
      get: (name: string) => {
        if (name === 'x-forwarded-proto') return 'http';
        if (name === 'x-forwarded-host') return 'localhost:3000';
        if (name === 'cookie') return 'from_header=1';
        return null;
      },
    });
    cookiesMock.mockResolvedValue({
      getAll: () => [{ name: 'sid', value: 'jar' }],
    });

    const { serverFetchBackend } = await import('@/lib/server-toaster-session');
    await serverFetchBackend('x');

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(new Headers(init.headers).get('cookie')).toBe('from_header=1');
  });

  it('uses jar cookies when header is empty', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response());
    vi.stubGlobal('fetch', fetchMock);

    headersMock.mockResolvedValue({
      get: (name: string) => {
        if (name === 'x-forwarded-proto') return 'http';
        if (name === 'host') return 'localhost:3000';
        if (name === 'cookie') return '';
        return null;
      },
    });
    cookiesMock.mockResolvedValue({
      getAll: () => [{ name: 'sid', value: 'from-jar' }],
    });

    const { serverFetchBackend } = await import('@/lib/server-toaster-session');
    await serverFetchBackend('/path');

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(new Headers(init.headers).get('cookie')).toBe('sid=from-jar');
  });

  it('normalizes path without leading slash', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response());
    vi.stubGlobal('fetch', fetchMock);

    headersMock.mockResolvedValue({
      get: (name: string) => {
        if (name === 'x-forwarded-proto') return 'http';
        if (name === 'host') return 'localhost:3000';
        return null;
      },
    });
    cookiesMock.mockResolvedValue({ getAll: () => [] });

    const { serverFetchBackend } = await import('@/lib/server-toaster-session');
    await serverFetchBackend('no-leading');

    expect(fetchMock.mock.calls[0][0]).toBe('http://localhost:3000/api/backend/no-leading');
  });
});
