import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import type { InboxDetail, InboxListItem } from '@/components/inbox/operator-inbox-view';
import { OperatorInboxClient } from '@/components/inbox/operator-inbox-client';
import { serverRailsBaseUrl } from '@/lib/toaster-api';

const OPS_TOKEN = process.env.OPS_AUTH_TOKEN ?? '';

async function requireToasterSession(): Promise<void> {
  const jar = await cookies();
  const cookieHeader = jar.getAll().map((c) => `${c.name}=${c.value}`).join('; ');
  const base = serverRailsBaseUrl();
  const res = await fetch(`${base}/auth/me`, {
    headers: { cookie: cookieHeader },
    cache: 'no-store',
  });
  if (!res.ok) {
    redirect('/login?returnTo=/inbox');
  }
}

export default async function InboxPage() {
  await requireToasterSession();
  const messages = await fetchInboxMessages();
  const selectedMessage = messages[0] ? await fetchInboxMessage(messages[0].id) : null;
  return (
    <OperatorInboxClient initialMessages={messages} initialSelectedMessage={selectedMessage} inboxApiBase="/api/ops" />
  );
}

async function fetchInboxMessages(): Promise<InboxListItem[]> {
  try {
    const base = serverRailsBaseUrl();
    const response = await fetch(`${base}/ops/inbox_messages`, {
      cache: 'no-store',
      headers: OPS_TOKEN ? { 'X-Ops-Token': OPS_TOKEN } : {},
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
    const base = serverRailsBaseUrl();
    const response = await fetch(`${base}/ops/inbox_messages/${messageId}`, {
      cache: 'no-store',
      headers: OPS_TOKEN ? { 'X-Ops-Token': OPS_TOKEN } : {},
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
            pendingDraft: (() => {
              const draft = bookingRequest.pending_draft as Record<string, unknown> | null | undefined;
              return draft && typeof draft.id === 'number' && typeof draft.body === 'string'
                ? { id: draft.id, body: draft.body }
                : null;
            })(),
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
