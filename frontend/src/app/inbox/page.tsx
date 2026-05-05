import { redirect } from 'next/navigation';
import { OperatorInboxClient } from '@/components/inbox/operator-inbox-client';
import type { ThreadDetail, ThreadListItem } from '@/components/inbox/operator-inbox-view';
import { parseThreadDetail, parseThreadListItem, threadToSearchParams } from '@/lib/ops-inbox';
import { serverRailsBaseUrl } from '@/lib/toaster-api';
import { serverFetchBackend } from '@/lib/server-toaster-session';

const OPS_TOKEN = process.env.OPS_AUTH_TOKEN ?? '';

async function requireToasterSession(): Promise<void> {
  const res = await serverFetchBackend('/auth/me');
  if (!res.ok) {
    redirect('/login?returnTo=/inbox');
  }
}

export default async function InboxPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireToasterSession();
  const sp = await searchParams;
  const threads = await fetchInboxThreads();

  let detail: ThreadDetail | null = null;
  const accountId = firstString(sp.account_id);
  const provider = firstString(sp.provider);
  const providerThreadId = firstString(sp.provider_thread_id);
  const anchorId = firstString(sp.anchor_inbox_message_id);

  if (accountId && provider && (providerThreadId || anchorId)) {
    const qs = new URLSearchParams();
    qs.set('account_id', accountId);
    qs.set('provider', provider);
    if (anchorId) qs.set('anchor_inbox_message_id', anchorId);
    if (providerThreadId) qs.set('provider_thread_id', providerThreadId);
    detail = await fetchInboxThreadView(qs.toString());
  } else if (threads[0]) {
    detail = await fetchInboxThreadView(threadToSearchParams(threads[0]).toString());
  }

  return (
    <OperatorInboxClient initialThreads={threads} initialThreadDetail={detail} inboxApiBase="/api/ops" />
  );
}

function firstString(v: string | string[] | undefined): string | undefined {
  if (Array.isArray(v)) return v[0];
  return v;
}

async function fetchInboxThreads(): Promise<ThreadListItem[]> {
  try {
    const base = serverRailsBaseUrl();
    const response = await fetch(`${base}/ops/inbox_threads`, {
      cache: 'no-store',
      headers: OPS_TOKEN ? { 'X-Ops-Token': OPS_TOKEN } : {},
    });

    if (!response.ok) {
      return [];
    }

    const body = await response.json();
    const rows = body.inbox_threads as Record<string, unknown>[] | undefined;
    if (!Array.isArray(rows)) return [];
    return rows.map((row) => parseThreadListItem(row));
  } catch {
    return [];
  }
}

async function fetchInboxThreadView(queryString: string): Promise<ThreadDetail | null> {
  try {
    const base = serverRailsBaseUrl();
    const response = await fetch(`${base}/ops/inbox_threads/view?${queryString}`, {
      cache: 'no-store',
      headers: OPS_TOKEN ? { 'X-Ops-Token': OPS_TOKEN } : {},
    });

    if (!response.ok) {
      return null;
    }

    const body = await response.json();
    return parseThreadDetail(body as Record<string, unknown>);
  } catch {
    return null;
  }
}
