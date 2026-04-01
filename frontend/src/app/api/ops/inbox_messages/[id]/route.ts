import { type NextRequest, NextResponse } from 'next/server';
import { opsApiUrl, opsAuthHeaders } from '@/lib/ops-auth';

export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  const { id } = await context.params;
  const response = await fetch(opsApiUrl(`/ops/inbox_messages/${id}`), {
    cache: 'no-store',
    headers: opsAuthHeaders(),
  });

  if (!response.ok) {
    return NextResponse.json(
      { error: 'Inbox message not found' },
      { status: response.status }
    );
  }

  const body = await response.json();
  return NextResponse.json(body);
}
