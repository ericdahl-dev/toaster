import Link from 'next/link';
import { AddEmailAccountForm } from '@/components/add-email-account-form';

const API_BASE_URL =
  process.env.TOASTER_API_BASE_URL ??
  process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ??
  'http://localhost:3001';

const ACCOUNT_ID =
  process.env.TOASTER_ACCOUNT_ID ?? process.env.NEXT_PUBLIC_TOASTER_ACCOUNT_ID ?? '1';

export default function EmailAccountsPage() {
  return (
    <main className="min-h-screen bg-zinc-50 px-6 py-16 text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50">
      <div className="mx-auto max-w-lg">
        <header className="mb-8 space-y-3">
          <nav className="mb-2">
            <Link
              href="/"
              className="text-xs font-medium uppercase tracking-[0.2em] text-zinc-500 hover:text-zinc-700 dark:text-zinc-400 dark:hover:text-zinc-200"
            >
              ← Toaster
            </Link>
          </nav>
          <h1 className="text-3xl font-semibold tracking-tight">Add email account</h1>
          <p className="text-sm leading-6 text-zinc-600 dark:text-zinc-400">
            Connect an IMAP mailbox so Toaster can ingest booking inquiries. Credentials are
            stored securely and never shared.
          </p>
        </header>

        <div className="rounded-3xl border border-zinc-200 bg-white p-8 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          <AddEmailAccountForm accountId={ACCOUNT_ID} apiBaseUrl={API_BASE_URL} />
        </div>
      </div>
    </main>
  );
}
