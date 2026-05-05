import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { SignOutButton } from '@/components/session/sign-out-button';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const toasterFetch = vi.hoisted(() =>
  vi.fn(() => Promise.resolve(new Response()))
);
const browserToasterApiBase = vi.hoisted(() => vi.fn(() => '/api/backend'));

vi.mock('@/lib/toaster-fetch', () => ({
  toasterFetch,
}));

vi.mock('@/lib/toaster-api', () => ({
  browserToasterApiBase,
}));

describe('SignOutButton', () => {
  beforeEach(() => {
    toasterFetch.mockClear();
    browserToasterApiBase.mockClear();
    const loc = { href: '' };
    Object.defineProperty(window, 'location', {
      configurable: true,
      writable: true,
      value: loc,
    });
  });

  it('POSTs logout to the browser API base then navigates to /login', async () => {
    render(<SignOutButton />);

    fireEvent.click(screen.getByRole('button', { name: /sign out/i }));

    await waitFor(() => {
      expect(browserToasterApiBase).toHaveBeenCalled();
      expect(toasterFetch).toHaveBeenCalledWith(
        '/api/backend/auth/logout',
        expect.objectContaining({ method: 'POST' })
      );
    });

    await waitFor(() => {
      expect(window.location.href).toBe('/login');
    });
  });
});
