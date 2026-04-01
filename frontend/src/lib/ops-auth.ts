const API_BASE_URL =
  process.env.TOASTER_API_BASE_URL ??
  process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ??
  'http://localhost:3001';

const OPS_USERNAME = process.env.OPS_USERNAME ?? 'ops';
const OPS_PASSWORD = process.env.OPS_PASSWORD ?? 'ops';

export function opsApiUrl(path: string): string {
  return `${API_BASE_URL}${path}`;
}

export function opsAuthHeaders(): HeadersInit {
  const credentials = Buffer.from(`${OPS_USERNAME}:${OPS_PASSWORD}`).toString('base64');
  return { Authorization: `Basic ${credentials}` };
}
