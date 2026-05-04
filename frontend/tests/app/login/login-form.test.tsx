import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi, beforeEach } from 'vitest';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn() }),
  useSearchParams: () => ({ get: () => null }),
}));

vi.mock('@/lib/toaster-api', () => ({
  browserToasterApiBase: () => 'http://localhost:3001',
}));

vi.mock('@/lib/toaster-fetch', () => ({
  toasterFetch: vi.fn(),
}));

import { toasterFetch } from '@/lib/toaster-fetch';
import { LoginForm } from '@/app/login/login-form';

describe('LoginForm', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('renders email, password, remember-me checkbox, and sign-in button', () => {
    render(<LoginForm />);

    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/remember me/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
  });

  it('remember-me checkbox is unchecked by default', () => {
    render(<LoginForm />);

    expect(screen.getByLabelText(/remember me/i)).not.toBeChecked();
  });

  it('toggles the remember-me checkbox', () => {
    render(<LoginForm />);

    const checkbox = screen.getByLabelText(/remember me/i);
    fireEvent.click(checkbox);
    expect(checkbox).toBeChecked();
    fireEvent.click(checkbox);
    expect(checkbox).not.toBeChecked();
  });

  it('submits with remember_me: false when unchecked', async () => {
    vi.mocked(toasterFetch).mockResolvedValue(new Response(null, { status: 200 }));

    render(<LoginForm />);

    fireEvent.change(screen.getByLabelText(/email/i), { target: { value: 'user@example.com' } });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'password123' } });
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(vi.mocked(toasterFetch)).toHaveBeenCalledWith(
        'http://localhost:3001/auth/login',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({ email: 'user@example.com', password: 'password123', remember_me: false }),
        }),
      );
    });
  });

  it('submits with remember_me: true when checked', async () => {
    vi.mocked(toasterFetch).mockResolvedValue(new Response(null, { status: 200 }));

    render(<LoginForm />);

    fireEvent.change(screen.getByLabelText(/email/i), { target: { value: 'user@example.com' } });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'password123' } });
    fireEvent.click(screen.getByLabelText(/remember me/i));
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(vi.mocked(toasterFetch)).toHaveBeenCalledWith(
        'http://localhost:3001/auth/login',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({ email: 'user@example.com', password: 'password123', remember_me: true }),
        }),
      );
    });
  });

  it('shows an error message on 401', async () => {
    vi.mocked(toasterFetch).mockResolvedValue(new Response('Unauthorized', { status: 401 }));

    render(<LoginForm />);

    fireEvent.change(screen.getByLabelText(/email/i), { target: { value: 'bad@example.com' } });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'wrong' } });
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(/invalid email or password/i);
    });
  });
});
