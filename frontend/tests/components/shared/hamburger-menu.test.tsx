import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { HamburgerMenu } from '@/components/shared/hamburger-menu';

const toasterFetch = vi.hoisted(() =>
  vi.fn(() => Promise.resolve(new Response())),
);
const browserToasterApiBase = vi.hoisted(() => vi.fn(() => '/api/backend'));

vi.mock('@/lib/toaster-fetch', () => ({
  toasterFetch,
}));

vi.mock('@/lib/toaster-api', () => ({
  browserToasterApiBase,
}));

describe('HamburgerMenu', () => {
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

  it('renders a toggle button', () => {
    render(<HamburgerMenu isAuthenticated={false} />);

    expect(screen.getByRole('button', { name: /open menu/i })).toBeInTheDocument();
  });

  it('does not show nav items when closed', () => {
    render(<HamburgerMenu isAuthenticated={true} />);

    expect(screen.queryByRole('link', { name: /operator inbox/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /email accounts/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /sign out/i })).not.toBeInTheDocument();
  });

  describe('when logged out', () => {
    it('shows only a Log in link when opened', () => {
      render(<HamburgerMenu isAuthenticated={false} />);

      fireEvent.click(screen.getByRole('button', { name: /open menu/i }));

      const loginLink = screen.getByRole('link', { name: /log in/i });
      expect(loginLink).toBeInTheDocument();
      expect(loginLink).toHaveAttribute('href', '/login');

      expect(screen.queryByRole('link', { name: /operator inbox/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('link', { name: /email accounts/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /sign out/i })).not.toBeInTheDocument();
    });
  });

  describe('when logged in', () => {
    it('shows authenticated nav links and a Sign out button', () => {
      render(<HamburgerMenu isAuthenticated={true} />);

      fireEvent.click(screen.getByRole('button', { name: /open menu/i }));

      const inboxLink = screen.getByRole('link', { name: /operator inbox/i });
      expect(inboxLink).toBeInTheDocument();
      expect(inboxLink).toHaveAttribute('href', '/inbox');

      const accountsLink = screen.getByRole('link', { name: /email accounts/i });
      expect(accountsLink).toBeInTheDocument();
      expect(accountsLink).toHaveAttribute('href', '/email-accounts');

      expect(screen.getByRole('button', { name: /sign out/i })).toBeInTheDocument();
      expect(screen.queryByRole('link', { name: /^log in$/i })).not.toBeInTheDocument();
    });

    it('closes the menu when a link is clicked', () => {
      render(<HamburgerMenu isAuthenticated={true} />);

      fireEvent.click(screen.getByRole('button', { name: /open menu/i }));
      expect(screen.getByRole('link', { name: /operator inbox/i })).toBeInTheDocument();

      fireEvent.click(screen.getByRole('link', { name: /operator inbox/i }));
      expect(screen.queryByRole('link', { name: /operator inbox/i })).not.toBeInTheDocument();
    });

    it('signs out via POST /auth/logout and navigates to /login', async () => {
      render(<HamburgerMenu isAuthenticated={true} />);

      fireEvent.click(screen.getByRole('button', { name: /open menu/i }));
      fireEvent.click(screen.getByRole('button', { name: /sign out/i }));

      await waitFor(() => {
        expect(browserToasterApiBase).toHaveBeenCalled();
        expect(toasterFetch).toHaveBeenCalledWith(
          '/api/backend/auth/logout',
          expect.objectContaining({ method: 'POST' }),
        );
      });

      await waitFor(() => {
        expect(window.location.href).toBe('/login');
      });
    });
  });

  it('closes the menu when Escape is pressed', () => {
    render(<HamburgerMenu isAuthenticated={true} />);

    fireEvent.click(screen.getByRole('button', { name: /open menu/i }));
    expect(screen.getByRole('link', { name: /operator inbox/i })).toBeInTheDocument();

    fireEvent.keyDown(document, { key: 'Escape' });
    expect(screen.queryByRole('link', { name: /operator inbox/i })).not.toBeInTheDocument();
  });

  it('updates aria-label and aria-expanded when toggled', () => {
    render(<HamburgerMenu isAuthenticated={false} />);

    const button = screen.getByRole('button', { name: /open menu/i });
    expect(button).toHaveAttribute('aria-expanded', 'false');
    expect(button).toHaveAttribute('aria-label', 'Open menu');

    fireEvent.click(button);
    expect(button).toHaveAttribute('aria-expanded', 'true');
    expect(button).toHaveAttribute('aria-label', 'Close menu');
  });
});
