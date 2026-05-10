# Project Instructions for AI Agents

## Useful Commands

- Sync GitHub issues into beads: `GITHUB_TOKEN="$(gh auth token --user Skeyelab)" bd github sync`

## Agent Skills

### Issue tracker

Issues live in GitHub Issues (`github.com/ericdahl-dev/toaster`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo: one `CONTEXT.md` + `docs/adr/` at the root. See `docs/agents/domain.md`.

## Build & Test

```bash
rvm use . && bundle exec rspec
```

## Learned User Preferences

- Use RVM to match the pinned Ruby (`rvm use .` from repo root) before `bundle`, `rspec`, or other gem commands so native extensions match the active interpreter.
- Prefer local test coverage only (SimpleCov); do not add Codecov or other remote coverage upload unless asked.
- Keep `parallel_rspec` usage local-only unless explicitly asked; CI should continue to run serial `bundle exec rspec`.
- Prefer self-documenting code: clear naming and structure first; use comments for non-obvious rationale (domain rules, invariants, security or performance tradeoffs), not to narrate obvious lines.

## Learned Workspace Facts

- Rails app lives at the repo root (moved from `backend/` in #135).
- Authentication is **Devise** (`devise_for :users`). Custom Devise views are in `app/views/users/`. The migration `add_password_digest_and_unique_email_to_users` is a historical artifact from a brief pre-Devise period — it does **not** mean the app uses `has_secure_password` or hand-rolled auth.
- Local dev serves the UI and API on different origins; the API uses `rack-cors` and `CORS_ORIGINS` (comma-separated) when defaults are not enough.
- Browser session cookies for the Rails app must be set and sent on the Next.js UI origin: use the same-origin `/api/backend` proxy for credential-bearing browser `fetch` calls. Pointing `NEXT_PUBLIC_TOASTER_API_BASE_URL` at another host (e.g. `http://127.0.0.1:3001`) sets cookies for that host while the page runs on `localhost` (or the reverse)—those hosts do not share a cookie jar, so `/auth/me` can return 401 after a "successful" login.
- After login, avoid relying on `router.replace` + `router.refresh()` alone for the next authenticated render; the RSC pass can run before `Set-Cookie` is visible to `cookies()`. Prefer a full-page navigation (or verify `/auth/me` before redirect) so the session cookie is present on the following request.
- The frontend defaults to account id `1` via env; development seeds create that account when missing—run `bin/rails db:seed` in development if IMAP or account-scoped API calls 404 with "account not found."
- Human login (email/password for the app session) is separate from IMAP and AgentMail connection credentials; an account may have multiple configured mail connections.
- On macOS, forked workers (e.g. Solid Queue) connecting to Postgres can hit a libpq GSS/Kerberos path that segfaults in the child; sets `PGGSSENCMODE=disable` when unset (`config/initializers/0_pg_gssenc_fork_safety.rb`).
- In `config/queue.yml`, worker `queues` must be a YAML array (e.g. `[default, webhooks, ai, mailers]`). A single comma-separated string is treated as one literal queue name, so jobs enqueued to real queues like `webhooks` are never claimed.
- For Solid Queue in local development on macOS, Puma can run the queue inline without forked workers: `plugin :solid_queue` and `solid_queue_mode :async` in `config/puma.rb` (development only). Alternatively, `SOLID_QUEUE_SUPERVISOR_MODE=async` for `./bin/rails solid_queue:start`.
- The GoodJob dashboard is mounted at `/jobs`.
- Ops JSON APIs use `OPS_AUTH_TOKEN` with the `X-Ops-Token` request header.
- Product/homepage copy describes Toaster as an email booking assistant (not Gmail-only); Gmail-specific backend routes may still exist until a deliberate deprecation pass.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
