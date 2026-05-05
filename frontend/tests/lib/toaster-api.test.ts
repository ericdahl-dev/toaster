import { browserToasterApiBase, serverRailsBaseUrl } from '@/lib/toaster-api';
import { beforeEach, describe, expect, it, vi } from 'vitest';

describe('toaster-api', () => {
  const envSnapshot = { ...process.env };

  beforeEach(() => {
    vi.unstubAllEnvs();
    process.env = { ...envSnapshot };
  });

  describe('serverRailsBaseUrl', () => {
    it('prefers TOASTER_API_BASE_URL over NEXT_PUBLIC_TOASTER_API_BASE_URL', () => {
      vi.stubEnv('TOASTER_API_BASE_URL', 'http://ops-api.example');
      vi.stubEnv('NEXT_PUBLIC_TOASTER_API_BASE_URL', 'http://ignored.example');
      expect(serverRailsBaseUrl()).toBe('http://ops-api.example');
    });

    it('falls back to NEXT_PUBLIC_TOASTER_API_BASE_URL when TOASTER_API_BASE_URL is unset', () => {
      delete process.env.TOASTER_API_BASE_URL;
      vi.stubEnv('NEXT_PUBLIC_TOASTER_API_BASE_URL', 'http://public.example');
      expect(serverRailsBaseUrl()).toBe('http://public.example');
    });

    it('defaults to localhost when neither env is set', () => {
      delete process.env.TOASTER_API_BASE_URL;
      delete process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL;
      expect(serverRailsBaseUrl()).toBe('http://127.0.0.1:3001');
    });
  });

  describe('browserToasterApiBase', () => {
    it('returns /api/backend when NEXT_PUBLIC_TOASTER_API_BASE_URL is unset', () => {
      delete process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL;
      expect(browserToasterApiBase()).toBe('/api/backend');
    });

    it('returns the path when env is a relative path under Next', () => {
      vi.stubEnv('NEXT_PUBLIC_TOASTER_API_BASE_URL', '/api/backend');
      expect(browserToasterApiBase()).toBe('/api/backend');
    });

    it('returns custom relative base when set', () => {
      vi.stubEnv('NEXT_PUBLIC_TOASTER_API_BASE_URL', '/custom/proxy');
      expect(browserToasterApiBase()).toBe('/custom/proxy');
    });

    it('uses / when env is only slash', () => {
      vi.stubEnv('NEXT_PUBLIC_TOASTER_API_BASE_URL', '/');
      expect(browserToasterApiBase()).toBe('/');
    });

    it('ignores absolute URLs and uses same-origin proxy path', () => {
      vi.stubEnv('NEXT_PUBLIC_TOASTER_API_BASE_URL', 'http://127.0.0.1:3001');
      expect(browserToasterApiBase()).toBe('/api/backend');
    });
  });
});
