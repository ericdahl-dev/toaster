/**
 * Rails API origin for server-side fetches (RSC, route handlers). Browser calls should use
 * {@link browserToasterApiBase} so session cookies stay on the Next origin.
 */
export function serverRailsBaseUrl(): string {
  return process.env.TOASTER_API_BASE_URL ?? process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ?? "http://127.0.0.1:3001";
}

/** Same-origin prefix proxied to Rails (see next.config.ts rewrites). */
export function browserToasterApiBase(): string {
  return process.env.NEXT_PUBLIC_TOASTER_API_BASE_URL ?? "/api/backend";
}
