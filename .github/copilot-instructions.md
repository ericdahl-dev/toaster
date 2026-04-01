# Copilot Instructions

## Project Overview

Toaster is a **multi-tenant SaaS AI booking assistant for venue inquiries**. It connects to Gmail,
ingests inbound booking emails, extracts structured request data, tracks workflow state, drafts
follow-up replies, and supports human approval when automation is not safe.

## Repo Layout

```
backend/    # Rails 7.2 API-only app (Ruby 3.3.6, PostgreSQL)
frontend/   # Next.js 16.2 operator dashboard (Node 22, TypeScript, Tailwind CSS v4)
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

## Backend (Rails API)

### Stack

- **Language / Framework:** Ruby 3.3.6, Rails 7.2 API-only
- **Database:** PostgreSQL (Neon in production; use `DATABASE_URL` for pooled connection,
  direct URL for migrations)
- **Job queue:** Solid Queue (`solid_queue` gem); job dashboard via Mission Control Jobs at `/jobs`
- **Web server:** Puma

### Conventions

- Follow **rubocop-rails-omakase** style (inherited in `.rubocop.yml`). Run `bundle exec rubocop`
  before committing backend changes.
- Use **RSpec** for all tests (`bundle exec rspec`). Place specs under `backend/spec/` mirroring
  the `app/` tree.
- Use **FactoryBot** for test data. Define factories in `backend/spec/factories/`.
- Keep controllers thin. Business logic belongs in service objects under `app/services/`.
- Background jobs live in `app/jobs/` and must be idempotent.
- Security scanning: `bundle exec brakeman -q` — resolve all warnings before merging.

### Key Models

| Model | Purpose |
|---|---|
| `Account` | Multi-tenant root |
| `BookingRequest` | Core entity; statuses: `pending → reviewing → confirmed / rejected / cancelled` |
| `GmailConnection` | OAuth'd Gmail mailbox per account |
| `Draft` | AI-generated email draft awaiting human approval |
| `EventLog` | Immutable audit trail |

### Testing

```bash
cd backend
bundle exec rspec                        # full suite
bundle exec rspec spec/models/           # models only
bundle exec rspec spec/requests/         # request specs
```

## Frontend (Next.js)

### Stack

- **Framework:** Next.js 16.2 (App Router), React 19, TypeScript 5
- **Styling:** Tailwind CSS v4 (`@tailwindcss/postcss`)
- **Testing:** Vitest + Testing Library (`jsdom` environment)
- **Linting:** ESLint with `eslint-config-next`
- **Package manager:** Yarn (Corepack-managed); use `yarn install --immutable`

### Conventions

- All source files live under `frontend/src/`. Use the App Router convention
  (`src/app/` for pages and layouts).
- Write TypeScript for all new files. Avoid `any`; use explicit types or generics.
- Co-locate tests with source files using the `.test.tsx` / `.test.ts` suffix.
- Use Tailwind utility classes for styling; avoid inline `style` props.
- Run `yarn lint` before committing frontend changes.

> ⚠️ **Next.js 16.2 has breaking changes** from earlier versions. Before writing any Next.js
> code, read the relevant guide in `node_modules/next/dist/docs/`. The App Router, Server
> Components, and data-fetching APIs may differ from your training data.

### Testing

```bash
cd frontend
yarn test            # single run (vitest)
yarn test:watch      # watch mode
```

## Development Setup

```bash
# Backend
cd backend && rvm use 3.3.6 && bundle install
bin/rails db:prepare
bin/rails s            # starts on :3000

# Frontend
cd frontend && nvm use 22.22.1 && corepack enable
yarn install --immutable
yarn dev               # starts on :3001 (or next available port)
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs `bundle exec rspec` and `yarn test` on every
push and pull request to `main`.
