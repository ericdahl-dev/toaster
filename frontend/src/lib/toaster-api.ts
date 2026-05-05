/**
 * Rails API origin for server-side fetches that do not need the browser session (e.g. ops
 * with `X-Ops-Token`). For `/auth/me` and other cookie auth, use `serverFetchBackend` from
 * `server-toaster-session.ts` so traffic uses `/api/backend`.
 */
export function serverRailsBaseUrl(): string {
  return process.env.TOASTER_API_BASE_URL ?? process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ?? "http://127.0.0.1:3001";
}

/**
 * Browser calls must use this Next proxy path so session cookies match the UI origin.
 * Absolute `NEXT_PUBLIC_TOASTER_API_BASE_URL` (e.g. `http://127.0.0.1:3001`) breaks cookie auth.
 */
export function browserToasterApiBase(): string {
  const raw = (process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ?? "").trim();
  if (raw.startsWith("/")) {
    return raw.length > 0 ? raw : "/api/backend";
  }
  return "/api/backend";
}
