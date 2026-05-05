import Link from 'next/link';
import { redirect } from 'next/navigation';
import { SignOutButton } from '@/components/session/sign-out-button';
import { ContactsClient } from '@/components/settings/contacts-client';
import { browserToasterApiBase } from '@/lib/toaster-api';
import { serverFetchBackend } from '@/lib/server-toaster-session';

async function requireToasterSession(): Promise<{ accountId: string }> {
  const res = await serverFetchBackend('/auth/me');
  if (!res.ok) {
    redirect('/login?returnTo=/settings/contacts');
  }
  const me = (await res.json()) as { account: { id: number } };
  return { accountId: String(me.account.id) };
}

export default async function ContactsPage() {
  const { accountId } = await requireToasterSession();
  const apiBaseUrl = browserToasterApiBase();

  return (
    <main className="min-h-screen bg-zinc-50 px-6 py-16 text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50">
      <div className="mx-auto max-w-lg">
        <header className="mb-8 space-y-3">
          <nav className="mb-2 flex flex-wrap items-center gap-4">
            <Link
              href="/settings"
              className="text-xs font-medium uppercase tracking-[0.2em] text-zinc-500 hover:text-zinc-700 dark:text-zinc-400 dark:hover:text-zinc-200"
            >
              ← Settings
            </Link>
            <SignOutButton />
          </nav>
          <h1 className="text-3xl font-semibold tracking-tight">Contacts</h1>
          <p className="text-sm leading-6 text-zinc-600 dark:text-zinc-400">
            View and edit contacts automatically created from inbound emails.
          </p>
        </header>

        <ContactsClient accountId={accountId} apiBaseUrl={apiBaseUrl} />
      </div>
    </main>
  );
}
