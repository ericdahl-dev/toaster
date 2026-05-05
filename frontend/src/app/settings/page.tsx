import Link from 'next/link';
import { redirect } from 'next/navigation';
import { SignOutButton } from '@/components/session/sign-out-button';
import { serverFetchBackend } from '@/lib/server-toaster-session';

async function requireToasterSession(): Promise<{ accountId: string }> {
  const res = await serverFetchBackend('/auth/me');
  if (!res.ok) {
    redirect('/login?returnTo=/settings');
  }
  const me = (await res.json()) as { account: { id: number } };
  return { accountId: String(me.account.id) };
}

export default async function SettingsPage() {
  await requireToasterSession();

  const sections = [
    {
      href: '/settings/venues',
      title: 'Venues',
      description: 'Manage the venue list used in booking requests.',
    },
    {
      href: '/settings/contacts',
      title: 'Contacts',
      description: 'View and edit contacts created from inbound emails.',
    },
    {
      href: '/settings/users',
      title: 'Users',
      description: 'Invite teammates and manage who has access.',
    },
  ];

  return (
    <main className="min-h-screen bg-zinc-50 px-6 py-16 text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50">
      <div className="mx-auto max-w-lg">
        <header className="mb-8 space-y-3">
          <nav className="mb-2 flex flex-wrap items-center gap-4">
            <Link
              href="/"
              className="text-xs font-medium uppercase tracking-[0.2em] text-zinc-500 hover:text-zinc-700 dark:text-zinc-400 dark:hover:text-zinc-200"
            >
              ← Toaster
            </Link>
            <SignOutButton />
          </nav>
          <h1 className="text-3xl font-semibold tracking-tight">Settings</h1>
          <p className="text-sm leading-6 text-zinc-600 dark:text-zinc-400">
            Manage your account data — venues, contacts, and team members.
          </p>
        </header>

        <div className="space-y-3">
          {sections.map(({ href, title, description }) => (
            <Link
              key={href}
              href={href}
              className="block rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm transition hover:border-zinc-300 hover:shadow-md dark:border-zinc-700 dark:bg-zinc-800 dark:hover:border-zinc-600"
            >
              <h2 className="text-base font-semibold text-zinc-900 dark:text-zinc-50">{title}</h2>
              <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">{description}</p>
            </Link>
          ))}
        </div>
      </div>
    </main>
  );
}
