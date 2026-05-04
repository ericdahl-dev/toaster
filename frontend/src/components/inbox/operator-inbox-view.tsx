import { DraftEmailPreview } from '@/components/email/draft-email-preview';

export type InboxListItem = {
  id: number;
  fromName: string | null;
  fromEmail: string | null;
  subject: string | null;
  receivedAt: string | null;
  bookingRequest: {
    id: number;
    status: string;
  } | null;
};

export type InboxDetail = {
  id: number;
  fromName: string | null;
  fromEmail: string | null;
  subject: string | null;
  receivedAt: string | null;
  bodyText: string | null;
  rawPayload: Record<string, unknown>;
  bookingRequest: {
    id: number;
    status: string;
    eventDate: string | null;
    headcount: number | null;
    budgetCents: number | null;
    missingFields: string[];
    reviewReasons: string[];
    pendingDraft: { id: number; body: string } | null;
  } | null;
};

export function OperatorInboxView({
  messages,
  selectedMessage,
  onSelectMessage,
}: {
  messages: InboxListItem[];
  selectedMessage: InboxDetail | null;
  onSelectMessage?: (messageId: number) => void;
}) {
  return (
    <main className="min-h-screen bg-zinc-50 px-6 py-10 text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50">
      <div className="mx-auto grid max-w-7xl gap-6 lg:grid-cols-[22rem_minmax(0,1fr)]">
        <section className="rounded-3xl border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          <header className="mb-4 space-y-1">
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-zinc-500 dark:text-zinc-400">
              Toaster
            </p>
            <h1 className="text-2xl font-semibold tracking-tight">Operator Inbox</h1>
            <p className="text-sm text-zinc-600 dark:text-zinc-400">
              Captured inbound mailbox messages for the current proof of concept.
            </p>
          </header>

          <div className="space-y-3">
            {messages.length === 0 ? (
              <p className="rounded-2xl border border-dashed border-zinc-300 px-4 py-6 text-sm text-zinc-500 dark:border-zinc-600 dark:text-zinc-400">
                No inbox messages yet.
              </p>
            ) : (
              messages.map((message) => {
                const isSelected = selectedMessage?.id === message.id;

                return (
                  <button
                    key={message.id}
                    type="button"
                    onClick={() => onSelectMessage?.(message.id)}
                    className={`flex w-full flex-col gap-2 rounded-2xl border px-4 py-3 text-left transition ${
                      isSelected
                        ? 'border-cyan-500 bg-cyan-50 dark:bg-cyan-950'
                        : 'border-zinc-200 bg-zinc-50 hover:border-zinc-300 hover:bg-white dark:border-zinc-700 dark:bg-zinc-900 dark:hover:border-zinc-600 dark:hover:bg-zinc-800'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <p className="text-sm font-semibold text-zinc-900 dark:text-zinc-100">
                          {message.subject || 'Untitled inquiry'}
                        </p>
                        <p className="text-xs text-zinc-600 dark:text-zinc-400">
                          {message.fromName || 'Unknown sender'}
                          {message.fromEmail ? ` · ${message.fromEmail}` : ''}
                        </p>
                      </div>
                      {message.bookingRequest ? (
                        <span className="rounded-full bg-zinc-900 px-2.5 py-1 text-[11px] font-medium uppercase tracking-wide text-white dark:bg-zinc-100 dark:text-zinc-900">
                          {message.bookingRequest.status}
                        </span>
                      ) : null}
                    </div>
                    <p className="text-xs text-zinc-500 dark:text-zinc-400">{formatDate(message.receivedAt)}</p>
                  </button>
                );
              })
            )}
          </div>
        </section>

        <section className="rounded-3xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          {!selectedMessage ? (
            <div className="flex min-h-[24rem] items-center justify-center rounded-2xl border border-dashed border-zinc-300 bg-zinc-50 px-6 text-center text-sm text-zinc-500 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-400">
              Select an inbox message to inspect the raw message and request snapshot.
            </div>
          ) : (
            <div className="space-y-6">
              <header className="space-y-2 border-b border-zinc-200 pb-4 dark:border-zinc-700">
                <h2 className="text-2xl font-semibold tracking-tight">
                  {selectedMessage.subject || 'Untitled inquiry'}
                </h2>
                <p className="text-sm text-zinc-600 dark:text-zinc-400">
                  {selectedMessage.fromName || 'Unknown sender'}
                  {selectedMessage.fromEmail ? ` · ${selectedMessage.fromEmail}` : ''}
                </p>
                <p className="text-xs text-zinc-500 dark:text-zinc-400">Received {formatDate(selectedMessage.receivedAt)}</p>
              </header>

              <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_20rem]">
                <article className="space-y-3">
                  <h3 className="text-sm font-semibold uppercase tracking-[0.16em] text-zinc-500 dark:text-zinc-400">
                    Raw message
                  </h3>
                  <div className="rounded-2xl border border-zinc-200 bg-zinc-50 p-4 dark:border-zinc-700 dark:bg-zinc-900">
                    <pre className="whitespace-pre-wrap break-words text-sm leading-6 text-zinc-800 dark:text-zinc-200">
                      {selectedMessage.bodyText || 'No plain-text body captured.'}
                    </pre>
                  </div>

                  <div className="rounded-2xl border border-zinc-200 bg-zinc-950 p-4 text-sm text-zinc-100 dark:border-zinc-700">
                    <p className="mb-2 text-xs font-semibold uppercase tracking-[0.16em] text-zinc-400">
                      Raw payload
                    </p>
                    <pre className="overflow-x-auto whitespace-pre-wrap break-all">
                      {JSON.stringify(selectedMessage.rawPayload, null, 2)}
                    </pre>
                  </div>

                  {selectedMessage.bookingRequest?.pendingDraft && (
                    <DraftEmailPreview
                      draftId={selectedMessage.bookingRequest.pendingDraft.id}
                      subject={selectedMessage.subject ?? 'Booking inquiry reply'}
                      bodyText={selectedMessage.bookingRequest.pendingDraft.body}
                    />
                  )}
                </article>

                <aside className="space-y-3">
                  <h3 className="text-sm font-semibold uppercase tracking-[0.16em] text-zinc-500 dark:text-zinc-400">
                    Request snapshot
                  </h3>

                  {selectedMessage.bookingRequest ? (
                    <div className="space-y-4 rounded-2xl border border-zinc-200 bg-zinc-50 p-4 text-sm text-zinc-800 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-200">
                      <Field label="Status" value={selectedMessage.bookingRequest.status} />
                      <Field label="Event date" value={selectedMessage.bookingRequest.eventDate ?? 'Unknown'} />
                      <Field
                        label="Headcount"
                        value={
                          selectedMessage.bookingRequest.headcount != null
                            ? `${selectedMessage.bookingRequest.headcount} guests`
                            : 'Unknown'
                        }
                      />
                      <Field
                        label="Budget"
                        value={
                          selectedMessage.bookingRequest.budgetCents != null
                            ? formatCurrency(selectedMessage.bookingRequest.budgetCents)
                            : 'Unknown'
                        }
                      />
                      <Field
                        label="Missing fields"
                        value={
                          selectedMessage.bookingRequest.missingFields.length > 0
                            ? selectedMessage.bookingRequest.missingFields.join(', ')
                            : 'None'
                        }
                      />
                      <Field
                        label="Review reasons"
                        value={
                          selectedMessage.bookingRequest.reviewReasons.length > 0
                            ? selectedMessage.bookingRequest.reviewReasons.join(', ')
                            : 'None'
                        }
                      />
                    </div>
                  ) : (
                    <div className="rounded-2xl border border-dashed border-zinc-300 bg-zinc-50 p-4 text-sm text-zinc-500 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-400">
                      No linked booking request yet.
                    </div>
                  )}
                </aside>
              </div>
            </div>
          )}
        </section>
      </div>
    </main>
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
