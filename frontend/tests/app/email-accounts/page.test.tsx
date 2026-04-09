import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import EmailAccountsPage from '@/app/email-accounts/page';

vi.mock('@/components/email-accounts/email-accounts-client', () => ({
  EmailAccountsClient: ({ accountId, apiBaseUrl }: { accountId: string; apiBaseUrl: string }) => (
    <div
      data-testid="email-accounts-client"
      data-account-id={accountId}
      data-api-base-url={apiBaseUrl}
    />
  ),
}));

describe('EmailAccountsPage', () => {
  it('renders the page heading', () => {
    render(<EmailAccountsPage />);

    expect(screen.getByRole('heading', { name: /email accounts/i })).toBeInTheDocument();
  });

  it('renders a back link to the home page', () => {
    render(<EmailAccountsPage />);

    const link = screen.getByRole('link', { name: /toaster/i });
    expect(link).toHaveAttribute('href', '/');
  });

  it('renders the form with the default account id and api base url', () => {
    render(<EmailAccountsPage />);

    const client = screen.getByTestId('email-accounts-client');
    expect(client).toBeInTheDocument();
    expect(client).toHaveAttribute('data-account-id', '1');
    expect(client).toHaveAttribute('data-api-base-url', 'http://localhost:3001');
  });
});
