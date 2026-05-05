'use client';

import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { useState } from 'react';
import { browserToasterApiBase } from '@/lib/toaster-api';
import { toasterFetch } from '@/lib/toaster-fetch';

export function LoginForm() {
  const searchParams = useSearchParams();
  const returnTo = searchParams.get('returnTo') ?? '/email-accounts';

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [rememberMe, setRememberMe] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const api = browserToasterApiBase();
      const res = await toasterFetch(`${api}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: email.trim(),
          password,
          remember_me: rememberMe,
        }),
      });
      if (!res.ok) {
        const detail = await res.text().catch(() => '');
        if (res.status === 401) {
          setError('Invalid email or password.');
        } else if (res.status === 404 || res.status === 502 || res.status === 503) {
          setError(
            'Could not reach the API. Run Rails on port 3001 (e.g. PORT=3001 bin/rails s) and use the /api/backend proxy from this app.',
          );
        } else {
          setError(
            `Sign-in failed (HTTP ${res.status}).${detail ? ` ${detail.slice(0, 120)}` : ''} If this is a fresh dev DB, run bin/rails db:migrate db:seed in backend, then use dev@toaster.local / password123.`,
          );
        }
        return;
      }
      // Full navigation so the session cookie from this response is applied before the next
      // document load (RSC `cookies()`). `router.replace` + `refresh` often runs too early.
      const path = returnTo.startsWith('/') ? returnTo : '/email-accounts';
      window.location.assign(path);
    } catch {
      setError('Network error. Try again.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="min-h-screen bg-zinc-50 px-6 py-16 text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50">
      <div className="mx-auto max-w-sm space-y-8">
        <nav>
          <Link
            href="/"
            className="text-xs font-medium uppercase tracking-[0.2em] text-zinc-500 hover:text-zinc-700 dark:text-zinc-400 dark:hover:text-zinc-200"
          >
            ← Toaster
          </Link>
        </nav>
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Sign in</h1>
          <p className="mt-2 text-sm text-zinc-600 dark:text-zinc-400">
            Use your Toaster account email and password (not your mailbox IMAP password).
          </p>
        </div>
        <form method="post" onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="email" className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300">
              Email
            </label>
            <input
              id="email"
              name="email"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm dark:border-zinc-600 dark:bg-zinc-800"
            />
          </div>
          <div>
            <label htmlFor="password" className="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300">
              Password
            </label>
            <input
              id="password"
              name="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm dark:border-zinc-600 dark:bg-zinc-800"
            />
          </div>
          <div className="flex items-center gap-2">
            <input
              id="remember_me"
              name="remember_me"
              type="checkbox"
              checked={rememberMe}
              onChange={(e) => setRememberMe(e.target.checked)}
              className="h-4 w-4 rounded border-zinc-300 text-zinc-900 focus:ring-zinc-500 dark:border-zinc-600 dark:bg-zinc-800"
            />
            <label
              htmlFor="remember_me"
              className="text-sm text-zinc-600 dark:text-zinc-400"
            >
              Keep me signed in on this device
            </label>
          </div>
          {error ? (
            <p className="text-sm text-red-600 dark:text-red-400" role="alert">
              {error}
            </p>
          ) : null}
          <button
            type="submit"
            disabled={submitting}
            className="w-full rounded-lg bg-zinc-900 px-3 py-2 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200"
          >
            {submitting ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
      </div>
    </main>
  );
}
