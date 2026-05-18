# Project Instructions for AI Agents

## Agent Skills

### Issue tracker

Issues live in GitHub Issues (`github.com/ericdahl-dev/toaster`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo: one `CONTEXT.md` + `docs/adr/` at the root. See `docs/agents/domain.md`.

## Secrets (Doppler)

All secrets are managed in **Doppler** (project `toaster`). To read a secret:

```bash
doppler secrets get SECRET_NAME --plain
```

To run a command with all secrets injected:

```bash
doppler run -- bundle exec rails ...
```

Key secrets: `RAILS_MASTER_KEY`, `OPENAI_API_KEY`, `UNSTRUCTURED_API_KEY`, `DATABASE_URL`.

Do **not** hardcode secrets or write them to files. Never commit `.env` files with real values.

## Build & Test

```bash
mise exec -- bundle exec rspec
```

## Learned User Preferences

- Use `mise exec --` (from repo root) before `bundle`, `rspec`, or other gem commands so native extensions match the pinned Ruby interpreter (`mise.toml` pins the version).
- Issue tracking is **GitHub Issues only** — use `gh issue` commands. Do not use `bd`, beads, or any other issue tracker.
- Prefer local test coverage only (SimpleCov); do not add Codecov or other remote coverage upload unless asked.
- Keep `parallel_rspec` usage local-only unless explicitly asked; CI should continue to run serial `bundle exec rspec`.
- Prefer self-documenting code: clear naming and structure first; use comments for non-obvious rationale (domain rules, invariants, security or performance tradeoffs), not to narrate obvious lines.

## Learned Workspace Facts

- Rails app lives at the repo root (moved from `backend/` in #135).
- Authentication is **Devise** (`devise_for :users`). Custom Devise views are in `app/views/users/`. The migration `add_password_digest_and_unique_email_to_users` is a historical artifact from a brief pre-Devise period — it does **not** mean the app uses `has_secure_password` or hand-rolled auth.
- Product UI is a **Rails+Hotwire monolith** (see ADR 0004). Session cookies are same-origin; no split Next.js API or `rack-cors` setup for the operator dashboard.
- Development seeds create account id `1` when missing—run `bin/rails db:seed` if account-scoped flows 404 with "account not found."
- Human login (email/password for the app session) is separate from IMAP and AgentMail connection credentials; an account may have multiple configured mail connections.
- On macOS, forked workers (e.g. GoodJob) connecting to Postgres can hit a libpq GSS/Kerberos path that segfaults in the child; set `PGGSSENCMODE=disable` when unset (`config/initializers/0_pg_gssenc_fork_safety.rb`).
- Background jobs use **GoodJob** (ADR 0003). Development runs async inside Puma (`config.good_job.execution_mode = :async`). Production uses a separate `bundle exec good_job start` worker.
- The GoodJob dashboard is mounted at `/jobs` (admin only).
- Ops JSON APIs use `OPS_AUTH_TOKEN` with the `X-Ops-Token` header and require `account_id` on each request to scope data to one tenant.
- Product/homepage copy describes Toaster as an email booking assistant (not Gmail-only); Gmail-specific backend routes may still exist until a deliberate deprecation pass.

## Session Completion

**When ending a work session**, complete ALL steps below. Work is NOT complete until `git push` succeeds.

1. **File issues for remaining work** — `gh issue create --title "..." --body "..."` for anything needing follow-up
2. **Run quality gates** (if code changed) — `bundle exec rspec`, linters
3. **Push to remote** — `git pull --rebase && git push`; verify `git status` shows "up to date with origin"
4. **Hand off** — Provide context for next session

**Critical rules:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing
- NEVER say "ready to push when you are" — YOU must push

## Cursor Cloud specific instructions

### Services

| Service | Start command | Notes |
|---------|--------------|-------|
| PostgreSQL 16 | `sudo pg_ctlcluster 16 main start` | Must be running before any Rails command. pgvector extension installed. |
| Rails (Puma) | `mise exec -- bin/rails server -b 0.0.0.0 -p 3000` | GoodJob runs async inside Puma in dev (no separate worker needed). |

### Environment variables

The following env vars are set in `~/.bashrc` and required for tests/dev:

- `PGGSSENCMODE=disable` — prevents libpq GSS segfaults in forked workers
- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` / `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` / `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` — required by tests that touch encrypted columns (e.g. `ImapConnection`). CI gets these from GitHub Secrets; locally, any 12+ char strings work.

### Key commands

- **Tests:** `mise exec -- bundle exec rspec` (see README for scoped runs)
- **Lint:** `mise exec -- bundle exec rubocop` (pre-existing offenses exist; use `-a` to auto-fix)
- **Tailwind build:** `mise exec -- bundle exec rails tailwindcss:build` (needed before first server start)
- **DB prepare:** `mise exec -- bin/rails db:prepare` (creates dev + test DBs, runs migrations)
- **DB seed:** `mise exec -- bin/rails db:seed` (creates Account id=1, dev user `dev@toaster.local` / `password123`)

### Gotchas

- Doppler is **not available** in Cloud Agent VMs. Do not use `bin/dev` (it wraps `doppler run`). Start Rails directly with `mise exec -- bin/rails server`.
- Sign-up (`/users/sign_up`) is disabled; use `db:seed` to create dev user, or Rails runner/console.
- `DATABASE_URL` is not needed when PostgreSQL runs locally via Unix socket (the default in `config/database.yml`).
