import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { OperatorInboxView } from '@/components/inbox/operator-inbox-view';

describe('OperatorInboxView', () => {
  it('renders an inbox list and the selected request snapshot', () => {
    render(
      <OperatorInboxView
        messages={[
          {
            id: 1,
            fromName: 'Jamie Lead',
            fromEmail: 'jamie@example.com',
            subject: 'Wedding inquiry',
            receivedAt: '2026-04-01T10:00:00Z',
            bookingRequest: { id: 10, status: 'reviewing' },
          },
          {
            id: 2,
            fromName: 'Taylor Lead',
            fromEmail: 'taylor@example.com',
            subject: 'Corporate dinner',
            receivedAt: '2026-04-01T09:00:00Z',
            bookingRequest: null,
          },
        ]}
        selectedMessage={{
          id: 1,
          fromName: 'Jamie Lead',
          fromEmail: 'jamie@example.com',
          subject: 'Wedding inquiry',
          receivedAt: '2026-04-01T10:00:00Z',
          bodyText: 'Looking for June 14, 2026 for 120 guests.',
          rawPayload: { messageId: 'msg-123' },
          bookingRequest: {
            id: 10,
            status: 'reviewing',
            eventDate: '2026-06-14',
            headcount: 120,
            budgetCents: null,
            missingFields: ['budget_cents'],
            reviewReasons: [],
            pendingDraft: null,
          },
        }}
      />
    );

    expect(screen.getByRole('heading', { name: /operator inbox/i })).toBeInTheDocument();
    expect(screen.getAllByText('Wedding inquiry')).toHaveLength(2);
    expect(screen.getByText('Corporate dinner')).toBeInTheDocument();
    expect(screen.getAllByText(/jamie@example.com/i)).toHaveLength(2);
    expect(screen.getByText(/^120 guests$/i)).toBeInTheDocument();
    expect(screen.getByText(/budget_cents/i)).toBeInTheDocument();
    expect(screen.getByText(/messageId/i)).toBeInTheDocument();
  });

  it('calls back when the operator selects a message from the list', () => {
    const onSelectMessage = vi.fn();

    render(
      <OperatorInboxView
        messages={[
          {
            id: 2,
            fromName: 'Taylor Lead',
            fromEmail: 'taylor@example.com',
            subject: 'Corporate dinner',
            receivedAt: '2026-04-01T09:00:00Z',
            bookingRequest: null,
          },
        ]}
        selectedMessage={null}
        onSelectMessage={onSelectMessage}
      />
    );

    fireEvent.click(screen.getByRole('button', { name: /corporate dinner/i }));

    expect(onSelectMessage).toHaveBeenCalledWith(2);
  });

  it('shows a placeholder when no message is selected', () => {
    render(<OperatorInboxView messages={[]} selectedMessage={null} />);

    expect(screen.getByText(/select an inbox message/i)).toBeInTheDocument();
  });

  it('shows the draft preview label when a pending draft is present', () => {
    render(
      <OperatorInboxView
        messages={[]}
        selectedMessage={{
          id: 3,
          fromName: 'Alex Booker',
          fromEmail: 'alex@example.com',
          subject: 'Gala dinner inquiry',
          receivedAt: '2026-04-01T08:00:00Z',
          bodyText: 'We need a venue for 200 guests.',
          rawPayload: {},
          bookingRequest: {
            id: 20,
            status: 'reviewing',
            eventDate: null,
            headcount: 200,
            budgetCents: null,
            missingFields: [],
            reviewReasons: [],
            pendingDraft: { id: 5, body: 'Thank you for your inquiry. We would love to host your event!' },
          },
        }}
      />,
    );

    expect(screen.getByText(/draft reply preview/i)).toBeInTheDocument();
    expect(screen.getByText(/pending approval/i)).toBeInTheDocument();
    expect(screen.getByText(/draft #5/i)).toBeInTheDocument();
  });
});
