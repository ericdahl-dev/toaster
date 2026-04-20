'use client';

import { render } from '@react-email/render';
import { useEffect, useState } from 'react';
import { BookingReplyEmail } from './booking-reply-email';

type DraftEmailPreviewProps = {
  draftId: number;
  subject: string;
  bodyText: string;
};

export function DraftEmailPreview({ draftId, subject, bodyText }: DraftEmailPreviewProps) {
  const [html, setHtml] = useState<string | null>(null);

  useEffect(() => {
    render(<BookingReplyEmail subject={subject} bodyText={bodyText} />).then(setHtml);
  }, [subject, bodyText]);

  return (
    <div className="space-y-2">
      <h3 className="text-sm font-semibold uppercase tracking-[0.16em] text-zinc-500 dark:text-zinc-400">
        Draft reply preview
      </h3>
      <div className="overflow-hidden rounded-2xl border border-amber-200 dark:border-amber-800">
        <div className="bg-amber-50 px-4 py-2 text-xs font-medium text-amber-700 dark:bg-amber-950 dark:text-amber-400">
          Pending approval · Draft #{draftId}
        </div>
        {html ? (
          <iframe
            srcDoc={html}
            title="Draft reply preview"
            className="h-96 w-full border-0 bg-white"
            sandbox="allow-same-origin"
          />
        ) : (
          <div className="flex h-96 items-center justify-center bg-white text-sm text-zinc-400">
            Loading preview…
          </div>
        )}
      </div>
    </div>
  );
}
