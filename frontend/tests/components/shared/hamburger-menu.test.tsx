import { render, screen, fireEvent } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { HamburgerMenu } from '@/components/shared/hamburger-menu';

describe('HamburgerMenu', () => {
  it('renders a toggle button', () => {
    render(<HamburgerMenu />);

    expect(screen.getByRole('button', { name: /open menu/i })).toBeInTheDocument();
  });

  it('does not show nav links when closed', () => {
    render(<HamburgerMenu />);

    expect(screen.queryByRole('link', { name: /operator inbox/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /email accounts/i })).not.toBeInTheDocument();
  });

  it('shows nav links after clicking the toggle button', () => {
    render(<HamburgerMenu />);

    fireEvent.click(screen.getByRole('button', { name: /open menu/i }));

    const inboxLink = screen.getByRole('link', { name: /operator inbox/i });
    expect(inboxLink).toBeInTheDocument();
    expect(inboxLink).toHaveAttribute('href', '/inbox');

    const accountsLink = screen.getByRole('link', { name: /email accounts/i });
    expect(accountsLink).toBeInTheDocument();
    expect(accountsLink).toHaveAttribute('href', '/email-accounts');
  });

  it('closes the menu when a link is clicked', () => {
    render(<HamburgerMenu />);

    fireEvent.click(screen.getByRole('button', { name: /open menu/i }));
    expect(screen.getByRole('link', { name: /operator inbox/i })).toBeInTheDocument();

    fireEvent.click(screen.getByRole('link', { name: /operator inbox/i }));
    expect(screen.queryByRole('link', { name: /operator inbox/i })).not.toBeInTheDocument();
  });

  it('closes the menu when Escape is pressed', () => {
    render(<HamburgerMenu />);

    fireEvent.click(screen.getByRole('button', { name: /open menu/i }));
    expect(screen.getByRole('link', { name: /operator inbox/i })).toBeInTheDocument();

    fireEvent.keyDown(document, { key: 'Escape' });
    expect(screen.queryByRole('link', { name: /operator inbox/i })).not.toBeInTheDocument();
  });

  it('updates aria-label and aria-expanded when toggled', () => {
    render(<HamburgerMenu />);

    const button = screen.getByRole('button', { name: /open menu/i });
    expect(button).toHaveAttribute('aria-expanded', 'false');
    expect(button).toHaveAttribute('aria-label', 'Open menu');

    fireEvent.click(button);
    expect(button).toHaveAttribute('aria-expanded', 'true');
    expect(button).toHaveAttribute('aria-label', 'Close menu');
  });
});
