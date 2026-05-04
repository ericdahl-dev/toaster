import { Suspense } from 'react';
import { LoginForm } from './login-form';

export default function LoginPage() {
  return (
    <Suspense
      fallback={
        <main className="min-h-screen bg-zinc-50 px-6 py-16 text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50">
          <p className="mx-auto max-w-sm text-sm text-zinc-500">Loading…</p>
        </main>
      }
    >
      <LoginForm />
    </Suspense>
  );
}
