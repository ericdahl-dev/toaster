import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

vi.mock('next/headers', () => ({
  cookies: async () => ({
    getAll: () => [],
  }),
  headers: async () =>
    new Headers({
      host: 'localhost:3000',
      'x-forwarded-proto': 'http',
    }),
}));

vi.mock('@/lib/server-toaster-session', () => ({
  serverFetchBackend: vi.fn(async () =>
    new Response(JSON.stringify({ account: { id: 1 } }), {
      status: 200,
      headers: {'Content-Type': 'application/json'},
    }),
  ),
}));

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
  it('renders the page heading', async () => {
    const { default: EmailAccountsPage } = await import('@/app/email-accounts/page');
    render(await EmailAccountsPage());

    expect(screen.getByRole('heading', { name: /email accounts/i })).toBeInTheDocument();
  });

  it('renders a back link to the home page', async () => {
    const { default: EmailAccountsPage } = await import('@/app/email-accounts/page');
    render(await EmailAccountsPage());

    const link = screen.getByRole('link', { name: /toaster/i });
    expect(link).toHaveAttribute('href', '/');
  });

  it('renders the form with the default account id and api base url', async () => {
    const { default: EmailAccountsPage } = await import('@/app/email-accounts/page');
    render(await EmailAccountsPage());

    const client = screen.getByTestId('email-accounts-client');
    expect(client).toBeInTheDocument();
    expect(client).toHaveAttribute('data-account-id', '1');
    expect(client).toHaveAttribute('data-api-base-url', '/api/backend');
  });
});
