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
    expect(screen.getByText(/email booking assistant/i)).toBeInTheDocument();
  });

  it('shows an invite-only notice', () => {
    render(<Home />);

    expect(screen.getByText(/invite only/i)).toBeInTheDocument();
  });
});
