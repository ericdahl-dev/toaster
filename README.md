# Toaster

[![CI](https://github.com/ericdahl-dev/toaster/actions/workflows/ci.yml/badge.svg)](https://github.com/ericdahl-dev/toaster/actions/workflows/ci.yml)

Toaster is a **multi-tenant AI booking assistant for venue inquiries**. It connects to email
inboxes (IMAP, AgentMailbox), ingests inbound booking requests, extracts structured data with
LLM assistance, tracks request lifecycle, drafts follow-up replies, and routes transactional
notifications through Resend — with human approval whenever automation is not safe to proceed
alone.

---

## Architecture

```
Email inbox (IMAP / AgentMailbox)
        │
        ▼
InboxIngestion::Sync  ←  GoodJob background worker
        │  upserts InboxMessages
        ▼
BookingRequests::Reconcile
        │  creates / updates BookingRequest
        │  runs FieldExtractor (LLM-assisted)
        ▼
BookingRequest  ←  system of record
  status: pending → reviewing → confirmed / cancelled; archive hides from default list (ADR 0008)
        │
        ├── Draft (AI-generated reply, pending_review → sent)
        │       └── Drafts::SmtpSender  →  SMTP send
        │
        └── EventLog (append-only audit trail)
```

**Stack:** Ruby 3.3.7 · Rails 8.1 (Hotwire/Turbo, Propshaft) · PostgreSQL · GoodJob

---

## Local Setup

Requires [RVM](https://rvm.io) and a local PostgreSQL instance (or a Neon connection string).

```bash
# 1. Install Ruby and gems
rvm use .
bundle install

# 2. Prepare the database
bin/rails db:prepare
bin/rails db:seed          # creates a default Account for development

# 3. Start the server (web + async job runner in the same Puma process)
bin/rails s
```

The app is served on `http://localhost:3000`.

To run GoodJob as a separate worker process (e.g. to use the dashboard):

```bash
bin/dev                    # starts web + worker via Procfile.dev
```

---

## Environment Variables

Secrets are managed with [Doppler](https://doppler.com). Run `doppler setup` in the repo root to link your local environment, then use `bin/dev` or `doppler run -- <command>` to inject secrets at runtime.

For reference, `.env.example` lists the variables the app expects:

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `DATABASE_URL` | Dev/Prod | — | PostgreSQL connection string. Omit to use a local Unix socket. |
| `OPS_AUTH_TOKEN` | Prod | `dev-ops-token` | Bearer token for ops JSON endpoints (`X-Ops-Token` header). Requests must include `account_id` to scope data to one tenant. |
| `JOB_CONCURRENCY` | Optional | `1` | Number of GoodJob worker threads. |
| `PGGSSENCMODE` | macOS | `disable` | Prevents libpq GSS segfault in forked workers (set automatically on macOS). |
| `RAILS_MASTER_KEY` | Prod | — | Decrypts `config/credentials.yml.enc`. |
| `RESEND_API_KEY` | Prod (when sending mail) | — | API key for Resend transactional email. If unset in production, the app still boots but skips delivery and logs a warning (useful for preview deploys). |

---

## Running Tests

```bash
bundle exec rspec                        # full suite
bundle exec rspec spec/models/           # models only
bundle exec rspec spec/requests/         # request (integration) specs
```

The CI suite runs automatically on every push and pull request via GitHub Actions.

---

## How It Works

1. **Inbox ingestion** — A scheduled `SyncInboxJob` polls each connected mailbox, fetches new
   messages, and upserts `InboxMessage` rows. Checkpoints advance after each run so restarts
   are safe.

2. **Reconciliation** — After each upsert, `BookingRequests::Reconcile` creates or updates the
   `BookingRequest` derived from that message and invokes `FieldExtractor` (LLM-assisted) to
   populate structured fields (event date, guest count, contact, etc.).

3. **Inbox filters** — Each mail connection carries keyword-based `InboxFilter` rules. Filters
   match subject lines (case-insensitive substring) in priority order and assign a venue to the
   booking request. No match leaves `venue_id` nil.

4. **Operator review** — The operator UI (Rails/Hotwire) lists booking requests. Operators
   **archive** rows to hide them from the default list (reversible; auto-unarchive on new inbound mail—see ADR 0008), transition status (`pending → reviewing → confirmed / cancelled`), approve or
   reject AI-generated draft replies, and monitor the event log.

5. **Draft sending** — Approving a draft enqueues `SendDraftJob`, which calls
   `Drafts::SmtpSender` to deliver via SMTP using the connection's credentials. On delivery the
   booking request moves to `confirmed`.

6. **Audit trail** — `EventLog` records every significant state change and external interaction,
   rendered chronologically on the booking request detail page.

7. **Transactional email templates** — Outbound transactional notifications are delivered via
   Resend. Author new template content using Resend's React Email workflow:
   https://resend.com/docs/knowledge-base/template-emails-with-react-email

---

## Key Principles

- **`BookingRequest` is the system of record.** All state flows through it.
- **LLMs assist; they do not own state.** AI suggestions go into `Draft` records and must be
  approved before any action is taken.
- **Every important action is logged.** Use `EventLog` for state changes and external
  interactions.
- **Ingestion and worker paths must be idempotent.** Jobs are safe to retry without side
  effects.
- **TDD is the default development style.** Write tests first; keep them close to the code they
  cover.

---

## Background Job Dashboard

GoodJob's web UI is mounted at `/jobs`.

- Access control for `/jobs` should match the rest of your Rails app deployment.

---

## Contributing

1. **Branch naming:** `feature/<issue-number>-short-slug` (e.g. `feature/42-smtp-sender`)
2. **TDD required:** write specs before or alongside the implementation.
3. **Green suite:** `bundle exec rspec` must pass with zero failures before opening a PR.
4. **Rubocop:** `bundle exec rubocop` must pass (style is `rubocop-rails-omakase`).
5. Open a PR against `main`; CI runs automatically.

---

## Troubleshooting

**GSS/Kerberos segfault on macOS (Solid Queue / GoodJob fork)**

libpq's GSS probe is unsafe in fork children on macOS. Set `PGGSSENCMODE=disable` in your
Doppler `dev` config (already included in `.env.example` for reference). The app sets this automatically when the variable is unset, but setting it explicitly avoids surprises.

**`/jobs` dashboard returns 404**

Confirm that the app booted with the GoodJob gem installed and that `/jobs` is mounted in
`config/routes.rb`.

**Database connection refused**

Make sure Postgres is running locally. For a Neon connection, set `DATABASE_URL` in Doppler with `?sslmode=require`. In test, `DATABASE_URL` is ignored — tests always hit local Postgres.
