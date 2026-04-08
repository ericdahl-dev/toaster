import { act, fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { ThemeToggle } from './theme-toggle';
import { ThemeProvider } from './theme-provider';

// Mock matchMedia for jsdom
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

function renderWithProvider() {
  return render(
    <ThemeProvider>
      <ThemeToggle />
    </ThemeProvider>
  );
}

describe('ThemeToggle', () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.classList.remove('dark');
  });

  it('renders Light, Dark, and System buttons', () => {
    renderWithProvider();

    expect(screen.getByRole('button', { name: /light/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /dark/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /system/i })).toBeInTheDocument();
  });

  it('has the System button pressed by default', () => {
    renderWithProvider();

    expect(screen.getByRole('button', { name: /system/i })).toHaveAttribute('aria-pressed', 'true');
    expect(screen.getByRole('button', { name: /light/i })).toHaveAttribute('aria-pressed', 'false');
    expect(screen.getByRole('button', { name: /dark/i })).toHaveAttribute('aria-pressed', 'false');
  });

  it('switches to dark mode when Dark is clicked', () => {
    renderWithProvider();

    fireEvent.click(screen.getByRole('button', { name: /dark/i }));

    expect(screen.getByRole('button', { name: /dark/i })).toHaveAttribute('aria-pressed', 'true');
    expect(document.documentElement.classList.contains('dark')).toBe(true);
    expect(localStorage.getItem('theme')).toBe('dark');
  });

  it('switches to light mode when Light is clicked', () => {
    renderWithProvider();

    fireEvent.click(screen.getByRole('button', { name: /dark/i }));
    fireEvent.click(screen.getByRole('button', { name: /light/i }));

    expect(screen.getByRole('button', { name: /light/i })).toHaveAttribute('aria-pressed', 'true');
    expect(document.documentElement.classList.contains('dark')).toBe(false);
    expect(localStorage.getItem('theme')).toBe('light');
  });

  it('switches back to system mode when System is clicked', () => {
    renderWithProvider();

    fireEvent.click(screen.getByRole('button', { name: /dark/i }));
    fireEvent.click(screen.getByRole('button', { name: /system/i }));

    expect(screen.getByRole('button', { name: /system/i })).toHaveAttribute('aria-pressed', 'true');
    expect(localStorage.getItem('theme')).toBe('system');
  });

  it('reads stored theme from localStorage on mount', async () => {
    localStorage.setItem('theme', 'dark');

    renderWithProvider();

    // Wait for useEffect to run
    await act(async () => {});

    expect(screen.getByRole('button', { name: /dark/i })).toHaveAttribute('aria-pressed', 'true');
  });
});
