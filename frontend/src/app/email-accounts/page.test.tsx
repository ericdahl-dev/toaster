import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import EmailAccountsPage from './page';

vi.mock('@/components/add-email-account-form', () => ({
  AddEmailAccountForm: ({ accountId, apiBaseUrl }: { accountId: string; apiBaseUrl: string }) => (
    <div data-testid="add-email-account-form" data-account-id={accountId} data-api-base-url={apiBaseUrl} />
  ),
}));

describe('EmailAccountsPage', () => {
  it('renders the page heading', () => {
    render(<EmailAccountsPage />);

    expect(screen.getByRole('heading', { name: /add email account/i })).toBeInTheDocument();
  });

  it('renders a back link to the home page', () => {
    render(<EmailAccountsPage />);

    const link = screen.getByRole('link', { name: /toaster/i });
    expect(link).toHaveAttribute('href', '/');
  });

  it('renders the form with the default account id and api base url', () => {
    render(<EmailAccountsPage />);

    const form = screen.getByTestId('add-email-account-form');
    expect(form).toBeInTheDocument();
    expect(form).toHaveAttribute('data-account-id', '1');
    expect(form).toHaveAttribute('data-api-base-url', 'http://localhost:3001');
  });
});
