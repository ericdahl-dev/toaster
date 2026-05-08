# Rails+Hotwire monolith replaces the Next.js frontend

Toaster was built as a Rails API + Next.js frontend. The split introduced CORS complexity, same-site cookie friction, a two-origin authentication model, and two deployment units — all documented as recurring pain in AGENTS.md — before the product shape was stable enough to justify an API surface. The operator dashboard has no external consumers and no mobile app requirement.

Collapsing to a single Rails app with ERB, Turbo, and Stimulus eliminates the API/cookie boundary entirely and matches the architecture of the companion voice-assistant project. The JSON API routes and `rack-cors` config are deleted as part of the migration. The `frontend/` directory is removed.

A separate React or native frontend can be extracted later if a mobile app or third-party integration makes an API surface worthwhile — that will be a deliberate new decision, not a reversion.

## Considered options

- **Keep Rails API + Next.js** — maintains the current split; defers the rewrite but continues to pay the cross-origin and dual-deployment tax.
- **Rails API + lighter frontend (e.g. Inertia.js)** — reduces some friction but keeps two rendering layers and doesn't eliminate the deployment split.
- **Rails+Hotwire monolith (chosen)** — single process, single deployment, no CORS, auth cookies just work.
