'use client';

import { useCallback, useEffect, useState } from 'react';
import { toasterFetch } from '@/lib/toaster-fetch';

export type UserRow = {
  id: number;
  name: string;
  email: string;
  created_at: string;
  updated_at: string;
};

type ListState =
  | { status: 'idle' | 'loading' }
  | { status: 'ok'; users: UserRow[] }
  | { status: 'error'; message: string };

type InviteForm = { name: string; email: string; password: string; passwordConfirmation: string };
type InviteStatus =
  | { type: 'idle' | 'submitting' }
  | { type: 'success' }
  | { type: 'error'; message: string };

const INPUT_CLASS =
  'w-full rounded-xl border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-cyan-500 focus:outline-none focus:ring-2 focus:ring-cyan-200 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-100 dark:placeholder:text-zinc-500 dark:focus:border-cyan-400 dark:focus:ring-cyan-900';

const EMPTY_INVITE: InviteForm = { name: '', email: '', password: '', passwordConfirmation: '' };

export function UsersClient({
  accountId,
  apiBaseUrl,
  currentUserId,
}: {
  accountId: string;
  apiBaseUrl: string;
  currentUserId: number;
}) {
  const [listState, setListState] = useState<ListState>({ status: 'idle' });
  const [inviteForm, setInviteForm] = useState<InviteForm>(EMPTY_INVITE);
  const [inviteStatus, setInviteStatus] = useState<InviteStatus>({ type: 'idle' });
  const [removingId, setRemovingId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setListState({ status: 'loading' });
    try {
      const res = await toasterFetch(`${apiBaseUrl}/accounts/${accountId}/users`);
      const body = (await res.json().catch(() => ({}))) as {
        users?: UserRow[];
        error?: string;
      };
      if (!res.ok) {
        setListState({ status: 'error', message: body.error ?? `Error ${res.status}` });
        return;
      }
      setListState({ status: 'ok', users: Array.isArray(body.users) ? body.users : [] });
    } catch {
      setListState({ status: 'error', message: 'Network error.' });
    }
  }, [accountId, apiBaseUrl]);

  useEffect(() => {
    void load();
  }, [load]);

  async function handleInvite(e: React.FormEvent) {
    e.preventDefault();
    if (!inviteForm.name.trim() || !inviteForm.email.trim() || !inviteForm.password) return;

    setInviteStatus({ type: 'submitting' });

    try {
      const res = await toasterFetch(`${apiBaseUrl}/accounts/${accountId}/users`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user: {
            name: inviteForm.name.trim(),
            email: inviteForm.email.trim(),
            password: inviteForm.password,
            password_confirmation: inviteForm.passwordConfirmation,
          },
        }),
      });

      if (res.ok) {
        setInviteForm(EMPTY_INVITE);
        setInviteStatus({ type: 'success' });
        await load();
      } else {
        const body = (await res.json().catch(() => ({}))) as { errors?: string[]; error?: string };
        const message =
          Array.isArray(body.errors) && body.errors.length > 0
            ? body.errors.join(', ')
            : body.error ?? 'Failed to add user.';
        setInviteStatus({ type: 'error', message });
      }
    } catch {
      setInviteStatus({ type: 'error', message: 'Network error.' });
    }
  }

  async function handleRemove(user: UserRow) {
    setRemovingId(user.id);
    try {
      const res = await toasterFetch(`${apiBaseUrl}/accounts/${accountId}/users/${user.id}`, {
        method: 'DELETE',
      });
      if (res.ok || res.status === 204) {
        await load();
      } else {
        const body = (await res.json().catch(() => ({}))) as { error?: string };
        if (body.error) alert(body.error);
      }
    } finally {
      setRemovingId(null);
    }
  }

  const users = listState.status === 'ok' ? listState.users : [];

  return (
    <div className="space-y-6">
      {/* User list */}
      <section className="rounded-3xl border border-zinc-200 bg-white shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <header className="px-6 pt-6 pb-4">
          <h2 className="text-lg font-semibold text-zinc-900 dark:text-zinc-50">Team members</h2>
        </header>

        {listState.status === 'loading' || listState.status === 'idle' ? (
          <p className="px-6 pb-6 text-sm text-zinc-500 dark:text-zinc-400" role="status">
            Loading…
          </p>
        ) : listState.status === 'error' ? (
          <div className="px-6 pb-6">
            <p className="text-sm text-red-600" role="alert">
              {listState.message}
            </p>
            <button
              type="button"
              onClick={() => void load()}
              className="mt-2 rounded-lg border border-red-300 bg-white px-3 py-1.5 text-xs font-medium text-red-900 hover:bg-red-50"
            >
              Retry
            </button>
          </div>
        ) : users.length === 0 ? (
          <p className="px-6 pb-6 text-sm text-zinc-600 dark:text-zinc-400">No users yet.</p>
        ) : (
          <ul className="divide-y divide-zinc-200 dark:divide-zinc-700" aria-label="Team members">
            {users.map((u) => {
              const isSelf = u.id === currentUserId;
              return (
                <li
                  key={u.id}
                  className="flex items-center justify-between gap-4 px-6 py-4"
                >
                  <div>
                    <p className="font-medium text-zinc-900 dark:text-zinc-50">
                      {u.name}
                      {isSelf && (
                        <span className="ml-2 text-xs font-normal text-zinc-400 dark:text-zinc-500">
                          (you)
                        </span>
                      )}
                    </p>
                    <p className="text-sm text-zinc-600 dark:text-zinc-400">{u.email}</p>
                  </div>
                  {!isSelf && (
                    <button
                      type="button"
                      disabled={removingId === u.id}
                      onClick={() => {
                        if (
                          window.confirm(
                            `Remove ${u.name} (${u.email}) from this account?`
                          )
                        ) {
                          void handleRemove(u);
                        }
                      }}
                      className="shrink-0 rounded-lg border border-red-200 bg-white px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-red-800 dark:bg-zinc-900 dark:text-red-400"
                    >
                      {removingId === u.id ? 'Removing…' : 'Remove'}
                    </button>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {/* Add user form */}
      <section className="rounded-3xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <h2 className="mb-4 text-lg font-semibold text-zinc-900 dark:text-zinc-50">
          Add team member
        </h2>

        {inviteStatus.type === 'success' && (
          <p
            role="status"
            className="mb-4 rounded-xl border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-800 dark:border-green-800 dark:bg-green-950 dark:text-green-300"
          >
            User added successfully.
          </p>
        )}

        {inviteStatus.type === 'error' && (
          <p
            role="alert"
            className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-800 dark:bg-red-950 dark:text-red-300"
          >
            {inviteStatus.message}
          </p>
        )}

        <form onSubmit={handleInvite} noValidate className="space-y-4">
          <div>
            <label
              htmlFor="user-name"
              className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300"
            >
              Name <span aria-hidden="true">*</span>
            </label>
            <input
              id="user-name"
              type="text"
              required
              placeholder="Jane Smith"
              value={inviteForm.name}
              onChange={(e) => setInviteForm((f) => ({ ...f, name: e.target.value }))}
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label
              htmlFor="user-email"
              className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300"
            >
              Email <span aria-hidden="true">*</span>
            </label>
            <input
              id="user-email"
              type="email"
              required
              autoComplete="off"
              placeholder="jane@example.com"
              value={inviteForm.email}
              onChange={(e) => setInviteForm((f) => ({ ...f, email: e.target.value }))}
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label
              htmlFor="user-password"
              className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300"
            >
              Password <span aria-hidden="true">*</span>
            </label>
            <input
              id="user-password"
              type="password"
              required
              autoComplete="new-password"
              placeholder="••••••••"
              value={inviteForm.password}
              onChange={(e) => setInviteForm((f) => ({ ...f, password: e.target.value }))}
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label
              htmlFor="user-password-confirmation"
              className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300"
            >
              Confirm password <span aria-hidden="true">*</span>
            </label>
            <input
              id="user-password-confirmation"
              type="password"
              required
              autoComplete="new-password"
              placeholder="••••••••"
              value={inviteForm.passwordConfirmation}
              onChange={(e) =>
                setInviteForm((f) => ({ ...f, passwordConfirmation: e.target.value }))
              }
              className={INPUT_CLASS}
            />
          </div>

          <div className="pt-2">
            <button
              type="submit"
              disabled={
                inviteStatus.type === 'submitting' ||
                !inviteForm.name.trim() ||
                !inviteForm.email.trim() ||
                !inviteForm.password
              }
              className="inline-flex w-full items-center justify-center rounded-full bg-zinc-950 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-zinc-800 disabled:cursor-not-allowed disabled:opacity-50 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200"
            >
              {inviteStatus.type === 'submitting' ? 'Adding…' : 'Add user'}
            </button>
          </div>
        </form>
      </section>
    </div>
  );
}
