import { toasterFetch } from '@/lib/toaster-fetch';
import { afterEach, describe, expect, it, vi } from 'vitest';

describe('toasterFetch', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('uses credentials include and default no-store cache', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response());
    vi.stubGlobal('fetch', fetchMock);

    await toasterFetch('/api/backend/foo');

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/backend/foo',
      expect.objectContaining({
        credentials: 'include',
        cache: 'no-store',
      }),
    );
  });

  it('allows overriding cache from init', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response());
    vi.stubGlobal('fetch', fetchMock);

    await toasterFetch('/x', { cache: 'force-cache' });

    expect(fetchMock).toHaveBeenCalledWith(
      '/x',
      expect.objectContaining({
        credentials: 'include',
        cache: 'force-cache',
      }),
    );
  });
});
