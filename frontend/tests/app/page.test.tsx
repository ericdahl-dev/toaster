import type { ImgHTMLAttributes } from 'react';
import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import Home from '@/app/page';

vi.mock('next/image', () => ({
  default: (props: ImgHTMLAttributes<HTMLImageElement>) => <img {...props} />,
}));

describe('Home', () => {
  it('shows a toaster-specific summary', () => {
    render(<Home />);

    expect(
      screen.getByRole('heading', { name: /toaster/i })
    ).toBeInTheDocument();
    expect(
      screen.getByText(/gmail booking assistant/i)
    ).toBeInTheDocument();
  });

  it('links to the operator inbox', () => {
    render(<Home />);

    const link = screen.getByRole('link', { name: /open operator inbox/i });
    expect(link).toBeInTheDocument();
    expect(link).toHaveAttribute('href', '/inbox');
  });

  it('links to the add email account page', () => {
    render(<Home />);

    const link = screen.getByRole('link', { name: /add email account/i });
    expect(link).toBeInTheDocument();
    expect(link).toHaveAttribute('href', '/email-accounts');
  });
});
