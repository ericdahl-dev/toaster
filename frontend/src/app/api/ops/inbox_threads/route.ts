import type { NextRequest } from 'next/server';
import { NextResponse } from 'next/server';
import { serverRailsBaseUrl } from '@/lib/toaster-api';

async function toasterSessionOk(request: NextRequest): Promise<boolean> {
  const origin = new URL(request.url).origin;
  const res = await fetch(`${origin}/api/backend/auth/me`, {
    headers: { cookie: request.headers.get('cookie') ?? '' },
    cache: 'no-store',
  });
  return res.ok;
}

export async function GET(request: NextRequest) {
  if (!(await toasterSessionOk(request))) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const token = process.env.OPS_AUTH_TOKEN?.trim();
  if (!token) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 503 });
  }

  const base = serverRailsBaseUrl();
  const upstream = await fetch(`${base}/ops/inbox_threads`, {
    headers: { 'X-Ops-Token': token },
    cache: 'no-store',
  });
  const body = await upstream.json().catch(() => ({}));
  return NextResponse.json(body, { status: upstream.status });
}
