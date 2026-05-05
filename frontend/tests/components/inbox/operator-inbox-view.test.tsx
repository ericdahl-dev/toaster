import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { OperatorInboxView, type ThreadDetail, type ThreadListItem } from '@/components/inbox/operator-inbox-view';

const sampleThread: ThreadListItem = {
  accountId: 1,
  provider: 'imap',
  kind: 'thread',
  providerThreadId: 't-1',
  anchorInboxMessageId: null,
  subject: 'Wedding inquiry',
  fromName: 'Jamie Lead',
  fromEmail: 'jamie@example.com',
  lastActivityAt: '2026-04-01T10:00:00Z',
  bookingRequest: { id: 10, status: 'reviewing' },
};

const sampleDetail: ThreadDetail = {
  accountId: 1,
  provider: 'imap',
  kind: 'thread',
  providerThreadId: 't-1',
  anchorInboxMessageId: null,
  multipleBookings: false,
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
  timeline: [
    {
      type: 'inbox_message',
      id: 1,
      direction: 'inbound',
      fromName: 'Jamie Lead',
      fromEmail: 'jamie@example.com',
      subject: 'Wedding inquiry',
      bodyText: 'Looking for June 14, 2026 for 120 guests.',
      rawPayload: { messageId: 'msg-123' },
      sort_at: '2026-04-01T10:00:00Z',
    },
  ],
};

describe('OperatorInboxView', () => {
  it('renders thread list, transcript, and request snapshot', () => {
    render(
      <OperatorInboxView
        threads={[
          sampleThread,
          {
            accountId: 1,
            provider: 'imap',
            kind: 'thread',
            providerThreadId: 't-2',
            anchorInboxMessageId: null,
            subject: 'Corporate dinner',
            fromName: 'Taylor Lead',
            fromEmail: 'taylor@example.com',
            lastActivityAt: '2026-04-01T09:00:00Z',
            bookingRequest: null,
          },
        ]}
        selectedThread={sampleDetail}
      />,
    );

    expect(screen.getByRole('heading', { name: /operator inbox/i })).toBeInTheDocument();
    expect(screen.getAllByText('Wedding inquiry').length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText('Corporate dinner')).toBeInTheDocument();
    expect(screen.getAllByText(/jamie@example.com/i).length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText(/^120 guests$/i)).toBeInTheDocument();
    expect(screen.getByText(/budget_cents/i)).toBeInTheDocument();
    expect(screen.getByText(/messageId/i)).toBeInTheDocument();
  });

  it('calls back when the operator selects a thread from the list', () => {
    const onSelectThread = vi.fn();

    render(
      <OperatorInboxView
        threads={[
          {
            accountId: 1,
            provider: 'imap',
            kind: 'thread',
            providerThreadId: 't-2',
            anchorInboxMessageId: null,
            subject: 'Corporate dinner',
            fromName: 'Taylor Lead',
            fromEmail: 'taylor@example.com',
            lastActivityAt: '2026-04-01T09:00:00Z',
            bookingRequest: null,
          },
        ]}
        selectedThread={null}
        onSelectThread={onSelectThread}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: /corporate dinner/i }));

    expect(onSelectThread).toHaveBeenCalledWith(
      expect.objectContaining({
        providerThreadId: 't-2',
        subject: 'Corporate dinner',
      }),
    );
  });

  it('shows a placeholder when no thread is selected', () => {
    render(<OperatorInboxView threads={[]} selectedThread={null} />);

    expect(screen.getByText(/select a thread to view the transcript/i)).toBeInTheDocument();
  });

  it('shows the draft preview label when a pending draft is in the timeline', () => {
    const detail: ThreadDetail = {
      ...sampleDetail,
      timeline: [
        {
          type: 'draft',
          id: 5,
          status: 'pending_review',
          body: 'Thank you for your inquiry. We would love to host your event!',
          default_collapsed: false,
          sort_at: '2026-04-01T11:00:00Z',
        },
      ],
    };

    render(<OperatorInboxView threads={[]} selectedThread={detail} />);

    expect(screen.getByText(/draft reply preview/i)).toBeInTheDocument();
    expect(screen.getByText(/pending approval/i)).toBeInTheDocument();
    expect(screen.getByText(/draft #5/i)).toBeInTheDocument();
  });

  it('shows a warning when multiple bookings share the thread', () => {
    render(
      <OperatorInboxView
        threads={[]}
        selectedThread={{
          ...sampleDetail,
          multipleBookings: true,
        }}
      />,
    );

    expect(screen.getByText(/multiple booking requests share this thread/i)).toBeInTheDocument();
  });
});
