## Learned User Preferences

- In the backend directory, use RVM to match the pinned Ruby (`rvm use .` from `backend/` or rely on project `.ruby-version`) before `bundle`, `rspec`, or other gem commands so native extensions match the active interpreter.
- Prefer local test coverage only (backend SimpleCov, frontend Vitest via `yarn test`); do not add Codecov or other remote coverage upload unless asked.

## Learned Workspace Facts

- Monorepo: Rails API under `backend/`, frontend under `frontend/`. Frontend-specific Next.js agent rules live in `frontend/AGENTS.md`.
- Local dev serves the UI and API on different origins; the API uses `rack-cors` and `CORS_ORIGINS` (comma-separated) when defaults are not enough.
- The frontend defaults to account id `1` via env; development seeds create that account when missing—run `bin/rails db:seed` in development if IMAP or account-scoped API calls 404 with “account not found.”
- On macOS, forked workers (e.g. Solid Queue) connecting to Postgres can hit a libpq GSS/Kerberos path that segfaults in the child; the backend sets `PGGSSENCMODE=disable` when unset (`config/initializers/0_pg_gssenc_fork_safety.rb`).
- In `backend/config/queue.yml`, worker `queues` must be a YAML array (e.g. `[default, webhooks, ai, mailers]`). A single comma-separated string is treated as one literal queue name, so jobs enqueued to real queues like `webhooks` are never claimed.
- For Solid Queue in local development on macOS, Puma can run the queue inline without forked workers: `plugin :solid_queue` and `solid_queue_mode :async` in `config/puma.rb` (development only). Alternatively, `SOLID_QUEUE_SUPERVISOR_MODE=async` for `./bin/rails solid_queue:start`.
- Mission Control (`/jobs`) needs CSS/JS served through an asset pipeline; this API-only app uses `sprockets-rails` plus `app/assets/config/manifest.js` (and asset dirs) so engine assets resolve under `/assets/...` instead of 404ing.
- Ops JSON APIs use `OPS_AUTH_TOKEN` with the `X-Ops-Token` request header. Mission Control uses HTTP basic auth outside `development`/`test` via `MISSION_CONTROL_USERNAME` / `MISSION_CONTROL_PASSWORD`.
- Product/homepage copy describes Toaster as an email booking assistant (not Gmail-only); Gmail-specific backend routes may still exist until a deliberate deprecation pass.
