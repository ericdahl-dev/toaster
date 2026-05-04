'use client';

import { useCallback, useEffect, useState } from 'react';
import { toasterFetch } from '@/lib/toaster-fetch';

export type AgentmailConnectionRow = {
  id: number;
  inbox_id: string;
  active: boolean;
  last_synced_at: string | null;
  created_at: string;
  updated_at: string;
};

type ListState =
  | { status: 'idle' | 'loading' }
  | { status: 'ok'; connections: AgentmailConnectionRow[] }
  | { status: 'error'; message: string };

type SyncState = 'idle' | 'syncing' | 'done' | 'error';

export function AgentmailConnectionsList({
  accountId,
  apiBaseUrl,
  refreshKey,
}: {
  accountId: string;
  apiBaseUrl: string;
  refreshKey: number;
}) {
  const [state, setState] = useState<ListState>({ status: 'idle' });
  const [syncState, setSyncState] = useState<Record<number, SyncState>>({});

  const load = useCallback(async () => {
    setState({ status: 'loading' });
    try {
      const response = await toasterFetch(`${apiBaseUrl}/accounts/${accountId}/agent_mailbox/connections`);
      const body = (await response.json().catch(() => ({}))) as {
        connections?: AgentmailConnectionRow[];
        error?: string;
      };

      if (!response.ok) {
        const message =
          typeof body.error === 'string' && body.error.length > 0
            ? body.error
            : `Could not load accounts (${response.status})`;
        setState({ status: 'error', message });
        return;
      }

      const connections = Array.isArray(body.connections) ? body.connections : [];
      setState({ status: 'ok', connections });
    } catch {
      setState({ status: 'error', message: 'Network error while loading accounts.' });
    }
  }, [accountId, apiBaseUrl]);

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      void load();
    }, 0);

    return () => clearTimeout(timeoutId);
  }, [load, refreshKey]);

  async function handleSync(connectionId: number) {
    setSyncState((s) => ({ ...s, [connectionId]: 'syncing' }));
    try {
      const response = await toasterFetch(
        `${apiBaseUrl}/accounts/${accountId}/agent_mailbox/connections/${connectionId}/sync`,
        { method: 'POST' }
      );
      if (response.ok) {
        setSyncState((s) => ({ ...s, [connectionId]: 'done' }));
        await load();
        setTimeout(() => setSyncState((s) => ({ ...s, [connectionId]: 'idle' })), 2000);
      } else {
        setSyncState((s) => ({ ...s, [connectionId]: 'error' }));
      }
    } catch {
      setSyncState((s) => ({ ...s, [connectionId]: 'error' }));
    }
  }

  if (state.status === 'loading' || state.status === 'idle') {
    return (
      <p className="text-sm text-zinc-500 dark:text-zinc-400" role="status">
        Loading connected accounts…
      </p>
    );
  }

  if (state.status === 'error') {
    return (
      <div className="space-y-3 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-900 dark:bg-red-950 dark:text-red-200">
        <p role="alert">{state.message}</p>
        <button
          type="button"
          onClick={() => void load()}
          className="rounded-lg border border-red-300 bg-white px-3 py-1.5 text-xs font-medium text-red-900 hover:bg-red-100 dark:border-red-800 dark:bg-red-900 dark:text-red-100 dark:hover:bg-red-800"
        >
          Retry
        </button>
      </div>
    );
  }

  if (state.status !== 'ok') {
    return null;
  }

  if (state.connections.length === 0) {
    return null;
  }

  return (
    <ul className="divide-y divide-zinc-200 dark:divide-zinc-600" aria-label="Connected AgentMail accounts">
      {state.connections.map((c) => {
        const cs = syncState[c.id] ?? 'idle';
        return (
          <li key={c.id} className="py-4 first:pt-0 last:pb-0">
            <div className="flex flex-col gap-1 sm:flex-row sm:items-baseline sm:justify-between">
              <span className="font-medium text-zinc-900 dark:text-zinc-50">{c.inbox_id}</span>
              <div className="flex items-center gap-3">
                <span
                  className={`text-xs font-medium uppercase tracking-wide ${
                    c.active ? 'text-green-600 dark:text-green-400' : 'text-zinc-400 dark:text-zinc-500'
                  }`}
                >
                  {c.active ? 'Active' : 'Inactive'}
                </span>
                {c.active && (
                  <button
                    type="button"
                    disabled={cs === 'syncing'}
                    onClick={() => void handleSync(c.id)}
                    aria-label={`Sync now for ${c.inbox_id}`}
                    className="rounded-lg border border-zinc-300 bg-white px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-300 dark:hover:bg-zinc-800"
                  >
                    {cs === 'syncing' ? 'Syncing…' : cs === 'done' ? 'Synced ✓' : cs === 'error' ? 'Failed' : 'Sync now'}
                  </button>
                )}
              </div>
            </div>
            <p className="mt-0.5 text-xs font-mono text-zinc-500 dark:text-zinc-500">AgentMail API</p>
            {c.last_synced_at && (
              <p className="mt-0.5 text-xs text-zinc-500 dark:text-zinc-500">
                Last synced: {new Date(c.last_synced_at).toLocaleString()}
              </p>
            )}
          </li>
        );
      })}
    </ul>
  );
}
