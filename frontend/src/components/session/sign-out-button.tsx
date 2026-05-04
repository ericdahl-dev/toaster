'use client';

import { browserToasterApiBase } from '@/lib/toaster-api';
import { toasterFetch } from '@/lib/toaster-fetch';

export function SignOutButton() {
  return (
    <button
      type="button"
      className="text-xs font-medium uppercase tracking-[0.2em] text-zinc-500 hover:text-zinc-700 dark:text-zinc-400 dark:hover:text-zinc-200"
      onClick={() => {
        const api = browserToasterApiBase();
        void toasterFetch(`${api}/auth/logout`, { method: 'POST' }).finally(() => {
          window.location.href = '/login';
        });
      }}
    >
      Sign out
    </button>
  );
}
