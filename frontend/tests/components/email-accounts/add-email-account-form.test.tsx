import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { AddEmailAccountForm } from '@/components/email-accounts/add-email-account-form';

const defaultProps = {
  accountId: '1',
  apiBaseUrl: 'http://localhost:3001',
};

describe('AddEmailAccountForm', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('renders all form fields', () => {
    render(<AddEmailAccountForm {...defaultProps} />);

    expect(screen.getByLabelText(/email provider/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/email address/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/imap server/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/port/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/ssl/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/inbox folder/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /add email account/i })).toBeInTheDocument();
  });

  it('pre-fills Gmail server settings when Gmail is selected', () => {
    render(<AddEmailAccountForm {...defaultProps} />);

    const providerSelect = screen.getByLabelText(/email provider/i);
    expect(providerSelect).toHaveValue('gmail');

    expect(screen.getByLabelText(/imap server/i)).toHaveValue('imap.gmail.com');
    expect(screen.getByLabelText(/port/i)).toHaveValue(993);
    expect(screen.getByLabelText(/ssl/i)).toBeChecked();
  });

  it('updates server settings when provider changes to Outlook', () => {
    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email provider/i), { target: { value: 'outlook' } });

    expect(screen.getByLabelText(/imap server/i)).toHaveValue('outlook.office365.com');
    expect(screen.getByLabelText(/port/i)).toHaveValue(993);
  });

  it('updates server settings when provider changes to Yahoo', () => {
    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email provider/i), { target: { value: 'yahoo' } });

    expect(screen.getByLabelText(/imap server/i)).toHaveValue('imap.mail.yahoo.com');
  });

  it('clears the host field when Other is selected', () => {
    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email provider/i), { target: { value: 'other' } });

    expect(screen.getByLabelText(/imap server/i)).toHaveValue('');
  });

  it('shows validation errors when submitting empty form', async () => {
    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.click(screen.getByRole('button', { name: /add email account/i }));

    await waitFor(() => {
      expect(screen.getByText(/email address is required/i)).toBeInTheDocument();
      expect(screen.getByText(/password is required/i)).toBeInTheDocument();
    });
  });

  it('shows an error for an invalid email format', async () => {
    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email address/i), {
      target: { value: 'not-an-email' },
    });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'secret' } });
    fireEvent.click(screen.getByRole('button', { name: /add email account/i }));

    await waitFor(() => {
      expect(screen.getByText(/valid email address/i)).toBeInTheDocument();
    });
  });

  it('shows an error when host is empty for Other provider', async () => {
    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email provider/i), { target: { value: 'other' } });
    fireEvent.change(screen.getByLabelText(/email address/i), {
      target: { value: 'user@example.com' },
    });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'secret' } });
    fireEvent.click(screen.getByRole('button', { name: /add email account/i }));

    await waitFor(() => {
      expect(screen.getByText(/imap server is required/i)).toBeInTheDocument();
    });
  });

  it('submits the form and shows success message on 201', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          connection: { id: 1, host: 'imap.gmail.com', username: 'test@gmail.com' },
        }),
      })
    );

    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email address/i), {
      target: { value: 'test@gmail.com' },
    });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'apppassword' } });
    fireEvent.click(screen.getByRole('button', { name: /add email account/i }));

    await waitFor(() => {
      expect(screen.getByRole('status')).toHaveTextContent(/added successfully/i);
    });

    expect(vi.mocked(fetch)).toHaveBeenCalledWith(
      'http://localhost:3001/accounts/1/imap/connections',
      expect.objectContaining({
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      })
    );
  });

  it('shows API error field when present (e.g. account not found)', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        json: async () => ({ error: 'Account not found' }),
      })
    );

    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email address/i), {
      target: { value: 'test@gmail.com' },
    });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'apppassword' } });
    fireEvent.click(screen.getByRole('button', { name: /add email account/i }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(/account not found/i);
    });
  });

  it('shows error message from server on failure', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        json: async () => ({ errors: ['Username has already been taken'] }),
      })
    );

    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email address/i), {
      target: { value: 'test@gmail.com' },
    });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'apppassword' } });
    fireEvent.click(screen.getByRole('button', { name: /add email account/i }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(/username has already been taken/i);
    });
  });

  it('shows a network error message when fetch throws', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('Network error')));

    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email address/i), {
      target: { value: 'test@gmail.com' },
    });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'apppassword' } });
    fireEvent.click(screen.getByRole('button', { name: /add email account/i }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(/network error/i);
    });
  });

  it('resets the form after a successful submission', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ connection: { id: 1 } }),
      })
    );

    render(<AddEmailAccountForm {...defaultProps} />);

    fireEvent.change(screen.getByLabelText(/email address/i), {
      target: { value: 'test@gmail.com' },
    });
    fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'secret' } });
    fireEvent.click(screen.getByRole('button', { name: /add email account/i }));

    await waitFor(() => {
      expect(screen.getByRole('status')).toBeInTheDocument();
    });

    expect(screen.getByLabelText(/email address/i)).toHaveValue('');
    expect(screen.getByLabelText(/password/i)).toHaveValue('');
  });
});
