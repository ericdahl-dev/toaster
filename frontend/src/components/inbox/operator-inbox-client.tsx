'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { toasterFetch } from '@/lib/toaster-fetch';
import { parseThreadDetail, threadToSearchParams } from '@/lib/ops-inbox';
import { OperatorInboxView, type ThreadDetail, type ThreadListItem } from './operator-inbox-view';

export function OperatorInboxClient({
  initialThreads,
  initialThreadDetail,
  inboxApiBase = '/api/ops',
}: {
  initialThreads: ThreadListItem[];
  initialThreadDetail: ThreadDetail | null;
  inboxApiBase?: string;
}) {
  const router = useRouter();
  const [selectedThread, setSelectedThread] = useState<ThreadDetail | null>(initialThreadDetail);

  async function handleSelectThread(thread: ThreadListItem) {
    const qs = threadToSearchParams(thread).toString();
    router.replace(`/inbox?${qs}`, { scroll: false });

    const response = await toasterFetch(`${inboxApiBase}/inbox_threads/view?${qs}`);
    if (!response.ok) {
      setSelectedThread(null);
      return;
    }

    const body = await response.json();
    setSelectedThread(parseThreadDetail(body as Record<string, unknown>));
  }

  return (
    <OperatorInboxView
      threads={initialThreads}
      selectedThread={selectedThread}
      onSelectThread={handleSelectThread}
    />
  );
}
