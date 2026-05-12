# Copilot Instructions

## Project Overview

Toaster is a **multi-tenant SaaS AI booking assistant for venue inquiries**. It connects to email
inboxes, ingests inbound booking requests, extracts structured request data, tracks workflow state,
drafts follow-up replies, and supports human approval when automation is not safe.

## Repo Layout

Rails app lives at the repo root (moved from `backend/` in #135).

```
app/        # Rails application code
config/     # Rails configuration
db/         # Migrations, seeds, schema
spec/       # RSpec test suite
Gemfile     # Ruby dependencies
Dockerfile  # Production image
```

## Core Architectural Principles

- **BookingRequest is the system of record.** All state flows through `BookingRequest`. Do not
  persist booking state in any other model.
- **LLMs assist; they do not own state.** AI suggestions go into `Draft` records and must be
  approved before any action is taken.
- **Every important action is logged.** Use `EventLog` to record significant state changes and
  external interactions.
- **Ingestion and worker paths must be idempotent.** Background jobs and sync paths must be safe
  to retry without side effects.
- **TDD is the default development style.** Write tests first; keep them close to the code they
  cover.

## Rails App

### Stack

- **Language / Framework:** Ruby 3.4.9, Rails 8.x
- **Database:** PostgreSQL (Neon in production; use `DATABASE_URL` for pooled connection,
  direct URL for migrations)
- **Job queue:** GoodJob; job dashboard at `/jobs`
- **Web server:** Puma

### Conventions

- Follow **rubocop-rails-omakase** style (inherited in `.rubocop.yml`). Run `bundle exec rubocop`
  before committing changes.
- Use **RSpec** for all tests (`bundle exec rspec`). Place specs under `spec/` mirroring
  the `app/` tree.
- Use **FactoryBot** for test data. Define factories in `spec/factories/`.
- Keep controllers thin. Business logic belongs in service objects under `app/services/`.
- Background jobs live in `app/jobs/` and must be idempotent.
- Security scanning: `bundle exec brakeman -q` — resolve all warnings before merging.

### Key Models

| Model | Purpose |
|---|---|
| `Account` | Multi-tenant root |
| `BookingRequest` | Core entity; statuses: `pending → reviewing → confirmed / rejected / cancelled` |
| `Draft` | AI-generated email draft awaiting human approval |
| `EventLog` | Immutable audit trail |

### Testing

```bash
bundle exec rspec                        # full suite
bundle exec rspec spec/models/           # models only
bundle exec rspec spec/requests/         # request specs
```

## Secrets

All secrets are managed in **Doppler** (project `toaster`). Never hardcode secrets or commit `.env`
files with real values.

```bash
doppler secrets get SECRET_NAME --plain   # read a single secret
doppler run -- bundle exec rails ...      # inject all secrets into a command
```

Key secrets: `RAILS_MASTER_KEY`, `OPENAI_API_KEY`, `UNSTRUCTURED_API_KEY`, `DATABASE_URL`.

## Development Setup

```bash
mise exec -- bundle install
mise exec -- bin/rails db:prepare
mise exec -- bin/rails s            # starts on :3000
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs `bundle exec rspec` on every push and pull
request to `main`.
