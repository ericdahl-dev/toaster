'use client';

import { useCallback, useEffect, useState } from 'react';
import { toasterFetch } from '@/lib/toaster-fetch';

export type Venue = {
  id: number;
  name: string;
  address: string | null;
  capacity: number | null;
  created_at: string;
  updated_at: string;
};

type ListState =
  | { status: 'idle' | 'loading' }
  | { status: 'ok'; venues: Venue[] }
  | { status: 'error'; message: string };

type FormState = { name: string; address: string; capacity: string };
type SubmitStatus = { type: 'idle' | 'submitting' } | { type: 'error'; message: string };

const INPUT_CLASS =
  'w-full rounded-xl border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-cyan-500 focus:outline-none focus:ring-2 focus:ring-cyan-200 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-100 dark:placeholder:text-zinc-500 dark:focus:border-cyan-400 dark:focus:ring-cyan-900';

const EMPTY_FORM: FormState = { name: '', address: '', capacity: '' };

export function VenuesClient({
  accountId,
  apiBaseUrl,
}: {
  accountId: string;
  apiBaseUrl: string;
}) {
  const [listState, setListState] = useState<ListState>({ status: 'idle' });
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [submitStatus, setSubmitStatus] = useState<SubmitStatus>({ type: 'idle' });
  const [deletingId, setDeletingId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setListState({ status: 'loading' });
    try {
      const res = await toasterFetch(`${apiBaseUrl}/accounts/${accountId}/venues`);
      const body = (await res.json().catch(() => ({}))) as { venues?: Venue[]; error?: string };
      if (!res.ok) {
        setListState({ status: 'error', message: body.error ?? `Error ${res.status}` });
        return;
      }
      setListState({ status: 'ok', venues: Array.isArray(body.venues) ? body.venues : [] });
    } catch {
      setListState({ status: 'error', message: 'Network error.' });
    }
  }, [accountId, apiBaseUrl]);

  useEffect(() => {
    void load();
  }, [load]);

  function startCreate() {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setSubmitStatus({ type: 'idle' });
  }

  function startEdit(venue: Venue) {
    setEditingId(venue.id);
    setForm({
      name: venue.name,
      address: venue.address ?? '',
      capacity: venue.capacity != null ? String(venue.capacity) : '',
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
      venue: {
        name: form.name.trim(),
        address: form.address.trim() || null,
        capacity: form.capacity.trim() ? Number(form.capacity) : null,
      },
    };

    const url =
      editingId != null
        ? `${apiBaseUrl}/accounts/${accountId}/venues/${editingId}`
        : `${apiBaseUrl}/accounts/${accountId}/venues`;

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
            : body.error ?? 'Failed to save venue.';
        setSubmitStatus({ type: 'error', message });
      }
    } catch {
      setSubmitStatus({ type: 'error', message: 'Network error.' });
    }
  }

  async function handleDelete(id: number) {
    setDeletingId(id);
    try {
      const res = await toasterFetch(`${apiBaseUrl}/accounts/${accountId}/venues/${id}`, {
        method: 'DELETE',
      });
      if (res.ok || res.status === 204) {
        await load();
      }
    } finally {
      setDeletingId(null);
    }
  }

  const isEditing = editingId !== null;
  const venues = listState.status === 'ok' ? listState.venues : [];

  return (
    <div className="space-y-6">
      {/* Venue list */}
      <section className="rounded-3xl border border-zinc-200 bg-white shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <header className="px-6 pt-6 pb-4">
          <h2 className="text-lg font-semibold text-zinc-900 dark:text-zinc-50">Venues</h2>
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
        ) : venues.length === 0 ? (
          <p className="px-6 pb-6 text-sm text-zinc-600 dark:text-zinc-400">No venues yet.</p>
        ) : (
          <ul
            className="divide-y divide-zinc-200 dark:divide-zinc-700"
            aria-label="Venues"
          >
            {venues.map((v) => (
              <li
                key={v.id}
                className="flex items-start justify-between gap-4 px-6 py-4"
              >
                <div>
                  <p className="font-medium text-zinc-900 dark:text-zinc-50">{v.name}</p>
                  {v.address && (
                    <p className="text-sm text-zinc-600 dark:text-zinc-400">{v.address}</p>
                  )}
                  {v.capacity != null && (
                    <p className="text-xs text-zinc-500 dark:text-zinc-500">
                      Capacity: {v.capacity}
                    </p>
                  )}
                </div>
                <div className="flex shrink-0 gap-2">
                  <button
                    type="button"
                    onClick={() => startEdit(v)}
                    className="rounded-lg border border-zinc-300 bg-white px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-300 dark:hover:bg-zinc-800"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    disabled={deletingId === v.id}
                    onClick={() => {
                      if (window.confirm(`Delete "${v.name}"? This cannot be undone.`)) {
                        void handleDelete(v.id);
                      }
                    }}
                    className="rounded-lg border border-red-200 bg-white px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-red-800 dark:bg-zinc-900 dark:text-red-400"
                  >
                    {deletingId === v.id ? 'Deleting…' : 'Delete'}
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
          {isEditing ? 'Edit venue' : 'Add venue'}
        </h2>

        {submitStatus.type === 'error' && (
          <p role="alert" className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-800 dark:bg-red-950 dark:text-red-300">
            {submitStatus.message}
          </p>
        )}

        <form onSubmit={handleSubmit} noValidate className="space-y-4">
          <div>
            <label htmlFor="venue-name" className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300">
              Name <span aria-hidden="true">*</span>
            </label>
            <input
              id="venue-name"
              type="text"
              required
              placeholder="Grand Ballroom"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label htmlFor="venue-address" className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300">
              Address
            </label>
            <input
              id="venue-address"
              type="text"
              placeholder="123 Main St"
              value={form.address}
              onChange={(e) => setForm((f) => ({ ...f, address: e.target.value }))}
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label htmlFor="venue-capacity" className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300">
              Capacity
            </label>
            <input
              id="venue-capacity"
              type="number"
              min={1}
              placeholder="200"
              value={form.capacity}
              onChange={(e) => setForm((f) => ({ ...f, capacity: e.target.value }))}
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
                  : 'Add venue'}
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

        {isEditing && (
          <button
            type="button"
            onClick={startCreate}
            className="mt-4 text-xs text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300"
          >
            + Add a new venue instead
          </button>
        )}
      </section>
    </div>
  );
}
