import type { InboxDetail, InboxListItem } from '@/components/operator-inbox-view';
import { OperatorInboxClient } from '@/components/operator-inbox-client';

const API_BASE_URL = process.env.TOASTER_API_BASE_URL ?? process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ?? 'http://localhost:3001';

export default async function InboxPage() {
  const messages = await fetchInboxMessages();
  const selectedMessage = messages[0] ? await fetchInboxMessage(messages[0].id) : null;

  return (
    <OperatorInboxClient initialMessages={messages} initialSelectedMessage={selectedMessage} apiBaseUrl={API_BASE_URL} />
  );
}

async function fetchInboxMessages(): Promise<InboxListItem[]> {
  try {
    const response = await fetch(`${API_BASE_URL}/ops/inbox_messages`, {
      cache: 'no-store',
    });

    if (!response.ok) {
      return [];
    }

    const body = await response.json();
    return body.inbox_messages.map((message: Record<string, unknown>) => ({
      id: Number(message.id),
      fromName: asNullableString(message.from_name),
      fromEmail: asNullableString(message.from_email),
      subject: asNullableString(message.subject),
      receivedAt: asNullableString(message.received_at),
      bookingRequest: message.booking_request
        ? {
            id: Number((message.booking_request as Record<string, unknown>).id),
            status: String((message.booking_request as Record<string, unknown>).status),
          }
        : null,
    }));
  } catch {
    return [];
  }
}

async function fetchInboxMessage(messageId: number): Promise<InboxDetail | null> {
  try {
    const response = await fetch(`${API_BASE_URL}/ops/inbox_messages/${messageId}`, {
      cache: 'no-store',
    });

    if (!response.ok) {
      return null;
    }

    const body = await response.json();
    const message = body.inbox_message as Record<string, unknown>;
    const bookingRequest = message.booking_request as Record<string, unknown> | null;

    return {
      id: Number(message.id),
      fromName: asNullableString(message.from_name),
      fromEmail: asNullableString(message.from_email),
      subject: asNullableString(message.subject),
      receivedAt: asNullableString(message.received_at),
      bodyText: asNullableString(message.body_text),
      rawPayload: (message.raw_payload as Record<string, unknown>) ?? {},
      bookingRequest: bookingRequest
        ? {
            id: Number(bookingRequest.id),
            status: String(bookingRequest.status),
            eventDate: asNullableString(bookingRequest.event_date),
            headcount: asNullableNumber(bookingRequest.headcount),
            budgetCents: asNullableNumber(bookingRequest.budget_cents),
            missingFields: asStringArray(bookingRequest.missing_fields),
            reviewReasons: asStringArray(bookingRequest.review_reasons),
          }
        : null,
    };
  } catch {
    return null;
  }
}

function asNullableString(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function asNullableNumber(value: unknown): number | null {
  return typeof value === 'number' ? value : null;
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : [];
}

export { fetchInboxMessages, fetchInboxMessage };
