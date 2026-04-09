'use client';

import { useState } from 'react';
import { AddEmailAccountForm } from '@/components/email-accounts/add-email-account-form';
import { ImapConnectionsList } from '@/components/email-accounts/imap-connections-list';

export function EmailAccountsClient({
  accountId,
  apiBaseUrl,
}: {
  accountId: string;
  apiBaseUrl: string;
}) {
  const [listVersion, setListVersion] = useState(0);

  return (
    <div className="space-y-8">
      <section className="rounded-3xl border border-zinc-200 bg-white p-8 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <h2 className="mb-4 text-lg font-semibold text-zinc-900 dark:text-zinc-50">
          Connected accounts
        </h2>
        <ImapConnectionsList
          accountId={accountId}
          apiBaseUrl={apiBaseUrl}
          refreshKey={listVersion}
        />
      </section>

      <div className="rounded-3xl border border-zinc-200 bg-white p-8 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <h2 className="mb-6 text-lg font-semibold text-zinc-900 dark:text-zinc-50">
          Add email account
        </h2>
        <AddEmailAccountForm
          accountId={accountId}
          apiBaseUrl={apiBaseUrl}
          onSuccess={() => setListVersion((n) => n + 1)}
        />
      </div>
    </div>
  );
}
