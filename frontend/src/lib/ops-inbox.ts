import type { BookingSnapshot, ThreadDetail, ThreadListItem, TimelineItem } from '@/components/inbox/operator-inbox-view';

export function parseThreadListItem(row: Record<string, unknown>): ThreadListItem {
  return {
    accountId: Number(row.account_id),
    provider: String(row.provider),
    kind: row.kind === 'singleton' ? 'singleton' : 'thread',
    providerThreadId: typeof row.provider_thread_id === 'string' ? row.provider_thread_id : null,
    anchorInboxMessageId:
      row.anchor_inbox_message_id != null && row.anchor_inbox_message_id !== ''
        ? Number(row.anchor_inbox_message_id)
        : null,
    subject: typeof row.subject === 'string' ? row.subject : null,
    fromName: typeof row.from_name === 'string' ? row.from_name : null,
    fromEmail: typeof row.from_email === 'string' ? row.from_email : null,
    lastActivityAt: typeof row.last_activity_at === 'string' ? row.last_activity_at : null,
    bookingRequest:
      row.booking_request && typeof row.booking_request === 'object'
        ? {
            id: Number((row.booking_request as Record<string, unknown>).id),
            status: String((row.booking_request as Record<string, unknown>).status),
          }
        : null,
  };
}

function parseTimelineItem(raw: Record<string, unknown>): TimelineItem {
  const t = String(raw.type);
  if (t === 'inbox_message') {
    return {
      type: 'inbox_message',
      id: Number(raw.id),
      direction: String(raw.direction),
      fromName: typeof raw.from_name === 'string' ? raw.from_name : null,
      fromEmail: typeof raw.from_email === 'string' ? raw.from_email : null,
      subject: typeof raw.subject === 'string' ? raw.subject : null,
      bodyText: typeof raw.body_text === 'string' ? raw.body_text : null,
      rawPayload: (raw.raw_payload as Record<string, unknown>) ?? {},
      sort_at: String(raw.sort_at),
    };
  }
  return {
    type: 'draft',
    id: Number(raw.id),
    status: String(raw.status),
    body: String(raw.body),
    default_collapsed: Boolean(raw.default_collapsed),
    sort_at: String(raw.sort_at),
  };
}

function parseBookingSnapshot(bookingRequest: Record<string, unknown> | null): BookingSnapshot | null {
  if (!bookingRequest) return null;
  const pending = bookingRequest.pending_draft as Record<string, unknown> | null | undefined;
  return {
    id: Number(bookingRequest.id),
    status: String(bookingRequest.status),
    eventDate: typeof bookingRequest.event_date === 'string' ? bookingRequest.event_date : null,
    headcount: typeof bookingRequest.headcount === 'number' ? bookingRequest.headcount : null,
    budgetCents: typeof bookingRequest.budget_cents === 'number' ? bookingRequest.budget_cents : null,
    missingFields: Array.isArray(bookingRequest.missing_fields)
      ? bookingRequest.missing_fields.filter((x): x is string => typeof x === 'string')
      : [],
    reviewReasons: Array.isArray(bookingRequest.review_reasons)
      ? bookingRequest.review_reasons.filter((x): x is string => typeof x === 'string')
      : [],
    pendingDraft:
      pending && typeof pending.id === 'number' && typeof pending.body === 'string'
        ? { id: pending.id, body: pending.body }
        : null,
  };
}

export function parseThreadDetail(body: Record<string, unknown>): ThreadDetail | null {
  const row = body.inbox_thread as Record<string, unknown> | undefined;
  if (!row) return null;
  const timelineRaw = row.timeline;
  const timeline: TimelineItem[] = Array.isArray(timelineRaw)
    ? timelineRaw.map((item) => parseTimelineItem(item as Record<string, unknown>))
    : [];

  return {
    accountId: Number(row.account_id),
    provider: String(row.provider),
    kind: row.kind === 'singleton' ? 'singleton' : 'thread',
    providerThreadId: typeof row.provider_thread_id === 'string' ? row.provider_thread_id : null,
    anchorInboxMessageId:
      row.anchor_inbox_message_id != null && row.anchor_inbox_message_id !== ''
        ? Number(row.anchor_inbox_message_id)
        : null,
    multipleBookings: Boolean(row.multiple_bookings),
    bookingRequest: parseBookingSnapshot((row.booking_request as Record<string, unknown>) ?? null),
    timeline,
  };
}

export function threadToSearchParams(thread: ThreadListItem): URLSearchParams {
  const p = new URLSearchParams();
  p.set('account_id', String(thread.accountId));
  p.set('provider', thread.provider);
  if (thread.kind === 'singleton' && thread.anchorInboxMessageId != null) {
    p.set('anchor_inbox_message_id', String(thread.anchorInboxMessageId));
  } else if (thread.providerThreadId) {
    p.set('provider_thread_id', thread.providerThreadId);
  }
  return p;
}
