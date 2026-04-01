'use client';

import { useState } from 'react';
import { OperatorInboxView, type InboxDetail, type InboxListItem } from './operator-inbox-view';

const API_BASE_URL = process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ?? 'http://localhost:3001';

export function OperatorInboxClient({
  initialMessages,
  initialSelectedMessage,
}: {
  initialMessages: InboxListItem[];
  initialSelectedMessage: InboxDetail | null;
}) {
  const [messages] = useState(initialMessages);
  const [selectedMessage, setSelectedMessage] = useState<InboxDetail | null>(initialSelectedMessage);

  async function handleSelectMessage(messageId: number) {
    const response = await fetch(`${API_BASE_URL}/ops/inbox_messages/${messageId}`);
    if (!response.ok) return;

    const body = await response.json();
    const message = body.inbox_message as Record<string, unknown>;
    const bookingRequest = message.booking_request as Record<string, unknown> | null;

    setSelectedMessage({
      id: Number(message.id),
      fromName: typeof message.from_name === 'string' ? message.from_name : null,
      fromEmail: typeof message.from_email === 'string' ? message.from_email : null,
      subject: typeof message.subject === 'string' ? message.subject : null,
      receivedAt: typeof message.received_at === 'string' ? message.received_at : null,
      bodyText: typeof message.body_text === 'string' ? message.body_text : null,
      rawPayload: (message.raw_payload as Record<string, unknown>) ?? {},
      bookingRequest: bookingRequest
        ? {
            id: Number(bookingRequest.id),
            status: String(bookingRequest.status),
            eventDate: typeof bookingRequest.event_date === 'string' ? bookingRequest.event_date : null,
            headcount: typeof bookingRequest.headcount === 'number' ? bookingRequest.headcount : null,
            budgetCents: typeof bookingRequest.budget_cents === 'number' ? bookingRequest.budget_cents : null,
            missingFields: Array.isArray(bookingRequest.missing_fields)
              ? bookingRequest.missing_fields.filter((item): item is string => typeof item === 'string')
              : [],
            reviewReasons: Array.isArray(bookingRequest.review_reasons)
              ? bookingRequest.review_reasons.filter((item): item is string => typeof item === 'string')
              : [],
          }
        : null,
    });
  }

  return (
    <OperatorInboxView
      messages={messages}
      selectedMessage={selectedMessage}
      onSelectMessage={handleSelectMessage}
    />
  );
}
