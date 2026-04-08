import Link from 'next/link';

export default function Home() {
  return (
    <main className="min-h-screen bg-zinc-50 px-6 py-16 text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50">
      <div className="mx-auto flex max-w-4xl flex-col gap-8">
        <header className="space-y-4">
          <p className="text-sm font-medium uppercase tracking-[0.2em] text-zinc-500 dark:text-zinc-400">
            Toaster
          </p>
          <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
            Toaster is a Gmail booking assistant.
          </h1>
          <p className="max-w-2xl text-lg leading-8 text-zinc-600 dark:text-zinc-400">
            It ingests booking inquiries, extracts structured details, tracks
            request state, and helps operators draft or send the next reply.
          </p>
        </header>

        <section className="grid gap-4 sm:grid-cols-3">
          {[
            'Rails API backend',
            'Next.js operator dashboard',
            'Neon Postgres + background jobs',
          ].map((item) => (
            <div
              key={item}
              className="rounded-2xl border border-zinc-200 bg-white p-4 shadow-sm dark:border-zinc-700 dark:bg-zinc-800"
            >
              <p className="text-sm font-medium text-zinc-700 dark:text-zinc-300">{item}</p>
            </div>
          ))}
        </section>

        <div className="flex flex-wrap gap-3">
          <Link
            href="/inbox"
            className="inline-flex items-center rounded-full bg-zinc-950 px-4 py-2 text-sm font-medium text-white transition hover:bg-zinc-800 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200"
          >
            Open operator inbox
          </Link>
          <Link
            href="/email-accounts"
            className="inline-flex items-center rounded-full border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-700 transition hover:border-zinc-400 hover:bg-zinc-50 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-300 dark:hover:border-zinc-500 dark:hover:bg-zinc-700"
          >
            Add email account
          </Link>
        </div>
      </div>
    </main>
  );
}
