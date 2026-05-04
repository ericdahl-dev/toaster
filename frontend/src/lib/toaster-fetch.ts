/** Fetch to the Toaster API with session cookies (same-origin when using `/api/backend`). */
export function toasterFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  return fetch(input, { ...init, credentials: "include" });
}
