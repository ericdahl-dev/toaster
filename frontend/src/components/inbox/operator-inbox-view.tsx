'use client';

import { useState } from 'react';
import { DraftEmailPreview } from '@/components/email/draft-email-preview';

export type ThreadListItem = {
  accountId: number;
  provider: string;
  kind: 'thread' | 'singleton';
  providerThreadId: string | null;
  anchorInboxMessageId: number | null;
  subject: string | null;
  fromName: string | null;
  fromEmail: string | null;
  lastActivityAt: string | null;
  bookingRequest: {
    id: number;
    status: string;
  } | null;
};

export type BookingSnapshot = {
  id: number;
  status: string;
  eventDate: string | null;
  headcount: number | null;
  budgetCents: number | null;
  missingFields: string[];
  reviewReasons: string[];
  pendingDraft: { id: number; body: string } | null;
};

export type ThreadDetail = {
  accountId: number;
  provider: string;
  kind: 'thread' | 'singleton';
  providerThreadId: string | null;
  anchorInboxMessageId: number | null;
  multipleBookings: boolean;
  bookingRequest: BookingSnapshot | null;
  timeline: TimelineItem[];
};

export type TimelineItem =
  | {
      type: 'inbox_message';
      id: number;
      direction: string;
      fromName: string | null;
      fromEmail: string | null;
      subject: string | null;
      bodyText: string | null;
      rawPayload: Record<string, unknown>;
      sort_at: string;
    }
  | {
      type: 'draft';
      id: number;
      status: string;
      body: string;
      default_collapsed: boolean;
      sort_at: string;
    };

export function OperatorInboxView({
  threads = [],
  selectedThread,
  onSelectThread,
}: {
  threads?: ThreadListItem[];
  selectedThread: ThreadDetail | null;
  onSelectThread?: (thread: ThreadListItem) => void;
}) {
  return (
    <main className="min-h-screen bg-zinc-50 px-6 py-10 text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50">
      <div className="mx-auto grid max-w-7xl gap-6 lg:grid-cols-[22rem_minmax(0,1fr)_20rem]">
        <section className="rounded-3xl border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          <header className="mb-4 space-y-1">
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-zinc-500 dark:text-zinc-400">
              Toaster
            </p>
            <h1 className="text-2xl font-semibold tracking-tight">Operator Inbox</h1>
            <p className="text-sm text-zinc-600 dark:text-zinc-400">
              Threads grouped by provider thread id; open one to see the full transcript and request snapshot.
            </p>
          </header>

          <div className="space-y-3">
            {threads.length === 0 ? (
              <p className="rounded-2xl border border-dashed border-zinc-300 px-4 py-6 text-sm text-zinc-500 dark:border-zinc-600 dark:text-zinc-400">
                No inbox threads yet.
              </p>
            ) : (
              threads.map((thread) => {
                const selected =
                  selectedThread &&
                  thread.accountId === selectedThread.accountId &&
                  thread.provider === selectedThread.provider &&
                  thread.kind === selectedThread.kind &&
                  thread.providerThreadId === selectedThread.providerThreadId &&
                  thread.anchorInboxMessageId === selectedThread.anchorInboxMessageId;

                return (
                  <button
                    key={`${thread.accountId}-${thread.provider}-${thread.kind}-${thread.providerThreadId ?? thread.anchorInboxMessageId}`}
                    type="button"
                    onClick={() => onSelectThread?.(thread)}
                    className={`flex w-full flex-col gap-2 rounded-2xl border px-4 py-3 text-left transition ${
                      selected
                        ? 'border-cyan-500 bg-cyan-50 dark:bg-cyan-950'
                        : 'border-zinc-200 bg-zinc-50 hover:border-zinc-300 hover:bg-white dark:border-zinc-700 dark:bg-zinc-900 dark:hover:border-zinc-600 dark:hover:bg-zinc-800'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <p className="text-sm font-semibold text-zinc-900 dark:text-zinc-100">
                          {thread.subject || 'Untitled inquiry'}
                        </p>
                        <p className="text-xs text-zinc-600 dark:text-zinc-400">
                          {thread.fromName || 'Unknown sender'}
                          {thread.fromEmail ? ` · ${thread.fromEmail}` : ''}
                        </p>
                        <p className="text-[11px] text-zinc-500 dark:text-zinc-500">
                          {thread.provider}
                          {thread.kind === 'singleton' ? ' · singleton' : ''}
                        </p>
                      </div>
                      {thread.bookingRequest ? (
                        <span className="rounded-full bg-zinc-900 px-2.5 py-1 text-[11px] font-medium uppercase tracking-wide text-white dark:bg-zinc-100 dark:text-zinc-900">
                          {thread.bookingRequest.status}
                        </span>
                      ) : null}
                    </div>
                    <p className="text-xs text-zinc-500 dark:text-zinc-400">{formatDate(thread.lastActivityAt)}</p>
                  </button>
                );
              })
            )}
          </div>
        </section>

        <section className="rounded-3xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          {!selectedThread ? (
            <div className="flex min-h-[24rem] items-center justify-center rounded-2xl border border-dashed border-zinc-300 bg-zinc-50 px-6 text-center text-sm text-zinc-500 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-400">
              Select a thread to view the transcript.
            </div>
          ) : (
            <ThreadTranscript thread={selectedThread} />
          )}
        </section>

        <aside className="rounded-3xl border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          <h3 className="mb-3 text-sm font-semibold uppercase tracking-[0.16em] text-zinc-500 dark:text-zinc-400">
            Request snapshot
          </h3>
          {!selectedThread ? (
            <div className="rounded-2xl border border-dashed border-zinc-300 bg-zinc-50 p-4 text-sm text-zinc-500 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-400">
              Select a thread to see booking fields.
            </div>
          ) : (
            <RequestSnapshotPanel thread={selectedThread} />
          )}
        </aside>
      </div>
    </main>
  );
}

function threadHeaderSubject(timeline: TimelineItem[]): string | null {
  for (const i of timeline) {
    if (i.type === 'inbox_message' && i.direction === 'inbound') return i.subject;
  }
  for (const i of timeline) {
    if (i.type === 'inbox_message') return i.subject;
  }
  return null;
}

function ThreadTranscript({ thread }: { thread: ThreadDetail }) {
  const previewSubject = threadHeaderSubject(thread.timeline);

  return (
    <div className="space-y-4">
      <header className="space-y-1 border-b border-zinc-200 pb-4 dark:border-zinc-700">
        <h2 className="text-xl font-semibold tracking-tight">{previewSubject || 'Thread'}</h2>
        <p className="text-xs text-zinc-500 dark:text-zinc-400">
          {thread.provider} · {thread.kind === 'singleton' ? `singleton #${thread.anchorInboxMessageId}` : thread.providerThreadId}
        </p>
      </header>
      <div className="flex max-h-[70vh] flex-col gap-3 overflow-y-auto pr-1">
        {thread.timeline.map((item) =>
          item.type === 'inbox_message' ? (
            <MessageBubble key={`m-${item.id}`} message={item} />
          ) : (
            <DraftBubble key={`d-${item.id}`} draft={item} subject={previewSubject} />
          ),
        )}
      </div>
    </div>
  );
}

function MessageBubble({
  message,
}: {
  message: Extract<TimelineItem, { type: 'inbox_message' }>;
}) {
  const outbound = message.direction === 'outbound';
  return (
    <div className={`flex ${outbound ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-[95%] rounded-2xl border px-4 py-3 text-sm ${
          outbound
            ? 'border-cyan-600 bg-cyan-50 text-zinc-900 dark:border-cyan-500 dark:bg-cyan-950 dark:text-zinc-100'
            : 'border-zinc-200 bg-zinc-50 text-zinc-900 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-100'
        }`}
      >
        <p className="text-[11px] font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
          {outbound ? 'Outbound' : 'Inbound'} · {message.fromName || message.fromEmail || '—'}
        </p>
        {message.subject ? <p className="mt-1 font-medium text-zinc-800 dark:text-zinc-200">{message.subject}</p> : null}
        <pre className="mt-2 whitespace-pre-wrap break-words font-sans text-zinc-800 dark:text-zinc-200">
          {message.bodyText || '—'}
        </pre>
        <details className="mt-2 text-[11px] text-zinc-500">
          <summary className="cursor-pointer">raw_payload</summary>
          <pre className="mt-1 overflow-x-auto whitespace-pre-wrap break-all">{JSON.stringify(message.rawPayload, null, 2)}</pre>
        </details>
      </div>
    </div>
  );
}

function DraftBubble({
  draft,
  subject,
}: {
  draft: Extract<TimelineItem, { type: 'draft' }>;
  subject: string | null | undefined;
}) {
  const [open, setOpen] = useState(!draft.default_collapsed);

  if (draft.default_collapsed && !open) {
    return (
      <div className="flex justify-end">
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="max-w-[95%] rounded-2xl border border-dashed border-zinc-400 bg-zinc-100 px-4 py-2 text-left text-sm text-zinc-600 dark:border-zinc-500 dark:bg-zinc-900 dark:text-zinc-400"
        >
          Rejected draft #{draft.id} (expand)
        </button>
      </div>
    );
  }

  return (
    <div className="flex justify-end">
      <div className="max-w-[95%] space-y-2 rounded-2xl border border-amber-500/60 bg-amber-50 px-4 py-3 text-sm dark:border-amber-500/50 dark:bg-amber-950/40">
        <p className="text-[11px] font-semibold uppercase tracking-wide text-amber-800 dark:text-amber-200">
          Draft · {draft.status.replace(/_/g, ' ')}
        </p>
        {draft.status === 'pending_review' ? (
          <DraftEmailPreview draftId={draft.id} subject={subject ?? 'Booking inquiry reply'} bodyText={draft.body} />
        ) : (
          <pre className="whitespace-pre-wrap break-words font-sans text-zinc-800 dark:text-zinc-200">{draft.body}</pre>
        )}
        {draft.default_collapsed ? (
          <button
            type="button"
            className="text-xs text-amber-900 underline dark:text-amber-200"
            onClick={() => setOpen(false)}
          >
            Collapse
          </button>
        ) : null}
      </div>
    </div>
  );
}

function RequestSnapshotPanel({ thread }: { thread: ThreadDetail }) {
  const br = thread.bookingRequest;

  return (
    <div className="space-y-3">
      {thread.multipleBookings ? (
        <p className="rounded-xl border border-amber-300 bg-amber-50 px-3 py-2 text-xs text-amber-950 dark:border-amber-700 dark:bg-amber-950/50 dark:text-amber-100">
          Multiple booking requests share this thread. Showing primary snapshot below.
        </p>
      ) : null}
      {br ? (
        <div className="space-y-4 rounded-2xl border border-zinc-200 bg-zinc-50 p-4 text-sm text-zinc-800 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-200">
          <Field label="Status" value={br.status} />
          <Field label="Event date" value={br.eventDate ?? 'Unknown'} />
          <Field
            label="Headcount"
            value={br.headcount != null ? `${br.headcount} guests` : 'Unknown'}
          />
          <Field
            label="Budget"
            value={br.budgetCents != null ? formatCurrency(br.budgetCents) : 'Unknown'}
          />
          <Field
            label="Missing fields"
            value={br.missingFields.length > 0 ? br.missingFields.join(', ') : 'None'}
          />
          <Field
            label="Review reasons"
            value={br.reviewReasons.length > 0 ? br.reviewReasons.join(', ') : 'None'}
          />
        </div>
      ) : (
        <div className="rounded-2xl border border-dashed border-zinc-300 bg-zinc-50 p-4 text-sm text-zinc-500 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-400">
          No linked booking request for the primary row.
        </div>
      )}
    </div>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="space-y-1">
      <p className="text-xs font-semibold uppercase tracking-[0.16em] text-zinc-500 dark:text-zinc-400">{label}</p>
      <p>{value}</p>
    </div>
  );
}

function formatCurrency(cents: number) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(cents / 100);
}

function formatDate(value: string | null) {
  if (!value) return 'Unknown time';

  return new Intl.DateTimeFormat('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'UTC',
  }).format(new Date(value));
}
