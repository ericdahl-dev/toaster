'use client';

import React, { useState } from 'react';
import { toasterFetch } from '@/lib/toaster-fetch';

type Provider = 'gmail' | 'outlook' | 'yahoo' | 'agentmail' | 'other';

type ProviderPreset = {
  label: string;
  host: string;
  port: number;
  ssl: boolean;
  passwordLabel: string;
  passwordHint?: React.ReactNode;
};

const PROVIDER_PRESETS: Record<Provider, ProviderPreset> = {
  gmail: {
    label: 'Gmail',
    host: 'imap.gmail.com',
    port: 993,
    ssl: true,
    passwordLabel: 'Password',
    passwordHint: (
      <>
        Use an{' '}
        <a
          href="https://support.google.com/accounts/answer/185833"
          target="_blank"
          rel="noopener noreferrer"
          className="underline hover:text-zinc-700 dark:hover:text-zinc-200"
        >
          app password
        </a>{' '}
        if 2-Step Verification is enabled.
      </>
    ),
  },
  outlook: { label: 'Outlook / Hotmail', host: 'outlook.office365.com', port: 993, ssl: true, passwordLabel: 'Password' },
  yahoo: { label: 'Yahoo Mail', host: 'imap.mail.yahoo.com', port: 993, ssl: true, passwordLabel: 'Password' },
  agentmail: {
    label: 'AgentMail',
    host: 'imap.agentmail.to',
    port: 993,
    ssl: true,
    passwordLabel: 'API key',
    passwordHint: (
      <>
        Find your API key in the{' '}
        <a
          href="https://console.agentmail.to/"
          target="_blank"
          rel="noopener noreferrer"
          className="underline hover:text-zinc-700 dark:hover:text-zinc-200"
        >
          AgentMail Console
        </a>{' '}
        under Dashboard → API Keys.
      </>
    ),
  },
  other: { label: 'Other / Manual', host: '', port: 993, ssl: true, passwordLabel: 'Password' },
};

type FormState = {
  provider: Provider;
  username: string;
  password: string;
  host: string;
  port: string;
  ssl: boolean;
  inboxFolder: string;
};

type FormErrors = Partial<Record<keyof FormState, string>>;

type SubmitStatus =
  | { type: 'idle' }
  | { type: 'submitting' }
  | { type: 'success' }
  | { type: 'error'; message: string };

export function AddEmailAccountForm({
  accountId,
  apiBaseUrl,
  onSuccess,
}: {
  accountId: string;
  apiBaseUrl: string;
  onSuccess?: () => void;
}) {
  const [form, setForm] = useState<FormState>({
    provider: 'gmail',
    username: '',
    password: '',
    host: PROVIDER_PRESETS.gmail.host,
    port: String(PROVIDER_PRESETS.gmail.port),
    ssl: PROVIDER_PRESETS.gmail.ssl,
    inboxFolder: 'INBOX',
  });
  const [status, setStatus] = useState<SubmitStatus>({ type: 'idle' });
  const [errors, setErrors] = useState<FormErrors>({});

  function handleProviderChange(provider: Provider) {
    const preset = PROVIDER_PRESETS[provider];
    setForm((prev) => ({
      ...prev,
      provider,
      host: preset.host,
      port: String(preset.port),
      ssl: preset.ssl,
    }));
  }

  function validate(): boolean {
    const newErrors: FormErrors = {};

    if (!form.username.trim()) {
      newErrors.username = 'Email address is required.';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.username.trim())) {
      newErrors.username = 'Please enter a valid email address.';
    }

    if (!form.password) {
      newErrors.password = 'Password is required.';
    }

    if (!form.host.trim()) {
      newErrors.host = 'IMAP server is required.';
    }

    const port = Number(form.port);
    if (!form.port.trim() || !Number.isInteger(port) || port <= 0) {
      newErrors.port = 'Port must be a positive whole number.';
    }

    if (!form.inboxFolder.trim()) {
      newErrors.inboxFolder = 'Inbox folder is required.';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    if (!validate()) return;

    setStatus({ type: 'submitting' });

    const isAgentmail = form.provider === 'agentmail';
    const endpoint = isAgentmail
      ? `${apiBaseUrl}/accounts/${accountId}/agent_mailbox/connections`
      : `${apiBaseUrl}/accounts/${accountId}/imap/connections`;
    const body = isAgentmail
      ? JSON.stringify({ agentmail_connection: { inbox_id: form.username.trim(), api_key: form.password } })
      : JSON.stringify({
          imap_connection: {
            username: form.username.trim(),
            password: form.password,
            host: form.host.trim(),
            port: Number(form.port),
            ssl: form.ssl,
            inbox_folder: form.inboxFolder.trim(),
          },
        });

    try {
      const response = await toasterFetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
      });

      if (response.ok) {
        setStatus({ type: 'success' });
        setForm({
          provider: 'gmail',
          username: '',
          password: '',
          host: PROVIDER_PRESETS.gmail.host,
          port: String(PROVIDER_PRESETS.gmail.port),
          ssl: PROVIDER_PRESETS.gmail.ssl,
          inboxFolder: 'INBOX',
        });
        setErrors({});
        onSuccess?.();
      } else {
        const body = await response.json().catch(() => ({})) as { errors?: unknown; error?: unknown };
        const message =
          typeof body.error === 'string' && body.error.length > 0
            ? body.error
            : Array.isArray(body.errors) && body.errors.length > 0
              ? (body.errors as string[]).join(', ')
              : 'Failed to add email account. Please check your details and try again.';
        setStatus({ type: 'error', message });
      }
    } catch {
      setStatus({ type: 'error', message: 'Network error. Please check your connection and try again.' });
    }
  }

  const inputClass =
    'w-full rounded-xl border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-cyan-500 focus:outline-none focus:ring-2 focus:ring-cyan-200 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-100 dark:placeholder:text-zinc-500 dark:focus:border-cyan-400 dark:focus:ring-cyan-900';

  const errorClass = 'mt-1 text-xs text-red-600';

  return (
    <form onSubmit={handleSubmit} noValidate className="space-y-6">
      {status.type === 'success' && (
        <div
          role="status"
          className="rounded-2xl border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-800 dark:border-green-800 dark:bg-green-950 dark:text-green-300"
        >
          Email account added successfully.
        </div>
      )}

      {status.type === 'error' && (
        <div
          role="alert"
          className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-800 dark:bg-red-950 dark:text-red-300"
        >
          {status.message}
        </div>
      )}

      <div className="space-y-1">
        <label htmlFor="provider" className="block text-sm font-medium text-zinc-700 dark:text-zinc-300">
          Email provider
        </label>
        <select
          id="provider"
          value={form.provider}
          onChange={(e) => handleProviderChange(e.target.value as Provider)}
          className={inputClass}
        >
          {(Object.entries(PROVIDER_PRESETS) as [Provider, (typeof PROVIDER_PRESETS)[Provider]][]).map(
            ([key, preset]) => (
              <option key={key} value={key}>
                {preset.label}
              </option>
            )
          )}
        </select>
      </div>

      <div className="space-y-1">
        <label htmlFor="username" className="block text-sm font-medium text-zinc-700 dark:text-zinc-300">
          {form.provider === 'agentmail' ? 'Inbox address' : 'Email address'}
        </label>
        <input
          id="username"
          type="email"
          autoComplete="email"
          placeholder="booking@yourvenue.com"
          value={form.username}
          onChange={(e) => setForm((prev) => ({ ...prev, username: e.target.value }))}
          aria-invalid={!!errors.username}
          aria-describedby={errors.username ? 'username-error' : undefined}
          className={inputClass}
        />
        {errors.username && (
          <p id="username-error" className={errorClass}>
            {errors.username}
          </p>
        )}
      </div>

      <div className="space-y-1">
        <label htmlFor="password" className="block text-sm font-medium text-zinc-700 dark:text-zinc-300">
          {PROVIDER_PRESETS[form.provider].passwordLabel}
        </label>
        <input
          id="password"
          type="password"
          autoComplete="current-password"
          placeholder="••••••••"
          value={form.password}
          onChange={(e) => setForm((prev) => ({ ...prev, password: e.target.value }))}
          aria-invalid={!!errors.password}
          aria-describedby={errors.password ? 'password-error' : undefined}
          className={inputClass}
        />
        {errors.password && (
          <p id="password-error" className={errorClass}>
            {errors.password}
          </p>
        )}
        {PROVIDER_PRESETS[form.provider].passwordHint && (
          <p className="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
            {PROVIDER_PRESETS[form.provider].passwordHint}
          </p>
        )}
      </div>

      {form.provider !== 'agentmail' && <fieldset className="space-y-4">
        <legend className="text-sm font-medium text-zinc-700 dark:text-zinc-300">Server settings</legend>

        <div className="space-y-1">
          <label htmlFor="host" className="block text-sm text-zinc-700 dark:text-zinc-300">
            IMAP server
          </label>
          <input
            id="host"
            type="text"
            placeholder="imap.example.com"
            value={form.host}
            onChange={(e) => setForm((prev) => ({ ...prev, host: e.target.value }))}
            aria-invalid={!!errors.host}
            aria-describedby={errors.host ? 'host-error' : undefined}
            className={inputClass}
          />
          {errors.host && (
            <p id="host-error" className={errorClass}>
              {errors.host}
            </p>
          )}
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1">
            <label htmlFor="port" className="block text-sm text-zinc-700 dark:text-zinc-300">
              Port
            </label>
            <input
              id="port"
              type="number"
              min={1}
              max={65535}
              value={form.port}
              onChange={(e) => setForm((prev) => ({ ...prev, port: e.target.value }))}
              aria-invalid={!!errors.port}
              aria-describedby={errors.port ? 'port-error' : undefined}
              className={inputClass}
            />
            {errors.port && (
              <p id="port-error" className={errorClass}>
                {errors.port}
              </p>
            )}
          </div>

          <div className="flex items-center gap-3 pt-6">
            <input
              id="ssl"
              type="checkbox"
              checked={form.ssl}
              onChange={(e) => setForm((prev) => ({ ...prev, ssl: e.target.checked }))}
              className="h-4 w-4 rounded border-zinc-300 accent-cyan-600"
            />
            <label htmlFor="ssl" className="text-sm text-zinc-700 dark:text-zinc-300">
              Use SSL / TLS
            </label>
          </div>
        </div>

        <div className="space-y-1">
          <label htmlFor="inboxFolder" className="block text-sm text-zinc-700 dark:text-zinc-300">
            Inbox folder
          </label>
          <input
            id="inboxFolder"
            type="text"
            placeholder="INBOX"
            value={form.inboxFolder}
            onChange={(e) => setForm((prev) => ({ ...prev, inboxFolder: e.target.value }))}
            aria-invalid={!!errors.inboxFolder}
            aria-describedby={errors.inboxFolder ? 'inboxFolder-error' : undefined}
            className={inputClass}
          />
          {errors.inboxFolder && (
            <p id="inboxFolder-error" className={errorClass}>
              {errors.inboxFolder}
            </p>
          )}
        </div>
      </fieldset>}

      <div className="pt-2">
        <button
          type="submit"
          disabled={status.type === 'submitting'}
          className="inline-flex w-full items-center justify-center rounded-full bg-zinc-950 px-6 py-2.5 text-sm font-medium text-white transition hover:bg-zinc-800 disabled:cursor-not-allowed disabled:opacity-50 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200"
        >
          {status.type === 'submitting' ? 'Adding account…' : 'Add email account'}
        </button>
      </div>
    </form>
  );
}
