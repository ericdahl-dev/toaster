/**
 * Rails API origin for server-side fetches that do not need the browser session (e.g. ops
 * with `X-Ops-Token`). For `/auth/me` and other cookie auth, use `serverFetchBackend` from
 * `server-toaster-session.ts` so traffic uses `/api/backend`.
 */
export function serverRailsBaseUrl(): string {
  return process.env.TOASTER_API_BASE_URL ?? process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ?? "http://127.0.0.1:3001";
}

/** Same-origin prefix proxied to Rails via `app/api/backend/[[...path]]/route.ts`. */
export function browserToasterApiBase(): string {
  return process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ?? "/api/backend";
}
