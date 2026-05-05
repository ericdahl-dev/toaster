'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { toasterFetch } from '@/lib/toaster-fetch';

export type Contact = {
  id: number;
  name: string;
  email: string | null;
  phone: string | null;
  created_at: string;
  updated_at: string;
};

type ListState =
  | { status: 'idle' | 'loading' }
  | { status: 'ok'; contacts: Contact[] }
  | { status: 'error'; message: string };

type FormState = { name: string; email: string; phone: string };
type SubmitStatus = { type: 'idle' | 'submitting' } | { type: 'error'; message: string };

const INPUT_CLASS =
  'w-full rounded-xl border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-cyan-500 focus:outline-none focus:ring-2 focus:ring-cyan-200 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-100 dark:placeholder:text-zinc-500 dark:focus:border-cyan-400 dark:focus:ring-cyan-900';

const EMPTY_FORM: FormState = { name: '', email: '', phone: '' };

export function ContactsClient({
  accountId,
  apiBaseUrl,
}: {
  accountId: string;
  apiBaseUrl: string;
}) {
  const [listState, setListState] = useState<ListState>({ status: 'idle' });
  const [query, setQuery] = useState('');
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [submitStatus, setSubmitStatus] = useState<SubmitStatus>({ type: 'idle' });
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const searchTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  const load = useCallback(
    async (q?: string) => {
      setListState({ status: 'loading' });
      const search = q !== undefined ? q : query;
      const params = search.trim() ? `?q=${encodeURIComponent(search.trim())}` : '';
      try {
        const res = await toasterFetch(
          `${apiBaseUrl}/accounts/${accountId}/contacts${params}`
        );
        const body = (await res.json().catch(() => ({}))) as {
          contacts?: Contact[];
          error?: string;
        };
        if (!res.ok) {
          setListState({ status: 'error', message: body.error ?? `Error ${res.status}` });
          return;
        }
        setListState({
          status: 'ok',
          contacts: Array.isArray(body.contacts) ? body.contacts : [],
        });
      } catch {
        setListState({ status: 'error', message: 'Network error.' });
      }
    },
    [accountId, apiBaseUrl, query]
  );

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function handleSearch(value: string) {
    setQuery(value);
    if (searchTimeout.current) clearTimeout(searchTimeout.current);
    searchTimeout.current = setTimeout(() => void load(value), 300);
  }

  function startEdit(contact: Contact) {
    setEditingId(contact.id);
    setForm({
      name: contact.name,
      email: contact.email ?? '',
      phone: contact.phone ?? '',
    });
    setSubmitStatus({ type: 'idle' });
  }

  function cancelEdit() {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setSubmitStatus({ type: 'idle' });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) return;

    setSubmitStatus({ type: 'submitting' });

    const payload = {
      contact: {
        name: form.name.trim(),
        email: form.email.trim() || null,
        phone: form.phone.trim() || null,
      },
    };

    const url =
      editingId != null
        ? `${apiBaseUrl}/accounts/${accountId}/contacts/${editingId}`
        : `${apiBaseUrl}/accounts/${accountId}/contacts`;

    try {
      const res = await toasterFetch(url, {
        method: editingId != null ? 'PATCH' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        setEditingId(null);
        setForm(EMPTY_FORM);
        setSubmitStatus({ type: 'idle' });
        await load();
      } else {
        const body = (await res.json().catch(() => ({}))) as { errors?: string[]; error?: string };
        const message =
          Array.isArray(body.errors) && body.errors.length > 0
            ? body.errors.join(', ')
            : body.error ?? 'Failed to save contact.';
        setSubmitStatus({ type: 'error', message });
      }
    } catch {
      setSubmitStatus({ type: 'error', message: 'Network error.' });
    }
  }

  async function handleDelete(contact: Contact) {
    setDeletingId(contact.id);
    try {
      const res = await toasterFetch(
        `${apiBaseUrl}/accounts/${accountId}/contacts/${contact.id}`,
        { method: 'DELETE' }
      );
      if (res.ok || res.status === 204) {
        await load();
      } else {
        const body = (await res.json().catch(() => ({}))) as { error?: string };
        if (body.error) {
          alert(body.error);
        }
      }
    } finally {
      setDeletingId(null);
    }
  }

  const isEditing = editingId !== null;
  const contacts = listState.status === 'ok' ? listState.contacts : [];

  return (
    <div className="space-y-6">
      {/* Search + list */}
      <section className="rounded-3xl border border-zinc-200 bg-white shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <header className="px-6 pt-6 pb-4">
          <h2 className="mb-3 text-lg font-semibold text-zinc-900 dark:text-zinc-50">Contacts</h2>
          <input
            type="search"
            placeholder="Search by name or email…"
            value={query}
            onChange={(e) => handleSearch(e.target.value)}
            className={INPUT_CLASS}
            aria-label="Search contacts"
          />
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
        ) : contacts.length === 0 ? (
          <p className="px-6 pb-6 text-sm text-zinc-600 dark:text-zinc-400">
            {query.trim() ? 'No contacts match your search.' : 'No contacts yet.'}
          </p>
        ) : (
          <ul className="divide-y divide-zinc-200 dark:divide-zinc-700" aria-label="Contacts">
            {contacts.map((c) => (
              <li key={c.id} className="flex items-start justify-between gap-4 px-6 py-4">
                <div>
                  <p className="font-medium text-zinc-900 dark:text-zinc-50">{c.name}</p>
                  {c.email && (
                    <p className="text-sm text-zinc-600 dark:text-zinc-400">{c.email}</p>
                  )}
                  {c.phone && (
                    <p className="text-xs text-zinc-500 dark:text-zinc-500">{c.phone}</p>
                  )}
                </div>
                <div className="flex shrink-0 gap-2">
                  <button
                    type="button"
                    onClick={() => startEdit(c)}
                    className="rounded-lg border border-zinc-300 bg-white px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-300 dark:hover:bg-zinc-800"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    disabled={deletingId === c.id}
                    onClick={() => {
                      if (
                        window.confirm(
                          `Delete contact "${c.name}"? This cannot be undone.`
                        )
                      ) {
                        void handleDelete(c);
                      }
                    }}
                    className="rounded-lg border border-red-200 bg-white px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-red-800 dark:bg-zinc-900 dark:text-red-400"
                  >
                    {deletingId === c.id ? 'Deleting…' : 'Delete'}
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      {/* Create / Edit form */}
      <section className="rounded-3xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <h2 className="mb-4 text-lg font-semibold text-zinc-900 dark:text-zinc-50">
          {isEditing ? 'Edit contact' : 'Add contact'}
        </h2>

        {submitStatus.type === 'error' && (
          <p
            role="alert"
            className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-800 dark:bg-red-950 dark:text-red-300"
          >
            {submitStatus.message}
          </p>
        )}

        <form onSubmit={handleSubmit} noValidate className="space-y-4">
          <div>
            <label
              htmlFor="contact-name"
              className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300"
            >
              Name <span aria-hidden="true">*</span>
            </label>
            <input
              id="contact-name"
              type="text"
              required
              placeholder="Jane Smith"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label
              htmlFor="contact-email"
              className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300"
            >
              Email
            </label>
            <input
              id="contact-email"
              type="email"
              placeholder="jane@example.com"
              value={form.email}
              onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label
              htmlFor="contact-phone"
              className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300"
            >
              Phone
            </label>
            <input
              id="contact-phone"
              type="tel"
              placeholder="+1 555 000 0000"
              value={form.phone}
              onChange={(e) => setForm((f) => ({ ...f, phone: e.target.value }))}
              className={INPUT_CLASS}
            />
          </div>

          <div className="flex gap-3 pt-2">
            <button
              type="submit"
              disabled={submitStatus.type === 'submitting' || !form.name.trim()}
              className="inline-flex items-center justify-center rounded-full bg-zinc-950 px-5 py-2 text-sm font-medium text-white transition hover:bg-zinc-800 disabled:cursor-not-allowed disabled:opacity-50 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200"
            >
              {submitStatus.type === 'submitting'
                ? isEditing
                  ? 'Saving…'
                  : 'Adding…'
                : isEditing
                  ? 'Save changes'
                  : 'Add contact'}
            </button>
            {isEditing && (
              <button
                type="button"
                onClick={cancelEdit}
                className="inline-flex items-center justify-center rounded-full border border-zinc-300 bg-white px-5 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-300"
              >
                Cancel
              </button>
            )}
          </div>
        </form>
      </section>
    </div>
  );
}
