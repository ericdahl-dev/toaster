## Learned User Preferences

- In the backend directory, use RVM to match the pinned Ruby (`rvm use .` from `backend/` or rely on project `.ruby-version`) before `bundle`, `rspec`, or other gem commands so native extensions match the active interpreter.

## Learned Workspace Facts

- Monorepo: Rails API under `backend/`, frontend under `frontend/`. Frontend-specific Next.js agent rules live in `frontend/AGENTS.md`.
- Local dev serves the UI and API on different origins; the API uses `rack-cors` and `CORS_ORIGINS` (comma-separated) when defaults are not enough.
- The frontend defaults to account id `1` via env; development seeds create that account when missing—run `bin/rails db:seed` in development if IMAP or account-scoped API calls 404 with “account not found.”
- On macOS, forked workers (e.g. Solid Queue) connecting to Postgres can hit a libpq GSS/Kerberos path that segfaults in the child; the backend sets `PGGSSENCMODE=disable` when unset (`config/initializers/0_pg_gssenc_fork_safety.rb`).
