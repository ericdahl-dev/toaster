# Toaster

Toaster is a multi-tenant SaaS AI booking assistant for venue inquiries. It connects to email inboxes, ingests inbound booking requests, extracts structured data, tracks workflow state, drafts follow-up replies, and supports human approval when automation is not safe.

## Stack

- **Backend:** Ruby 3.3.7, Rails 7.2 API + Hotwire, PostgreSQL, GoodJob
- **Infra:** Coolify (self-hosted), Neon (Postgres), Docker

## Local setup

Requires RVM and a local Postgres instance.

```bash
rvm use .
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails s
```

## Tests

```bash
bundle exec rspec
```

## Background jobs

Mission Control is mounted at `/jobs`. In development, no auth required. In production, set `MISSION_CONTROL_USERNAME` and `MISSION_CONTROL_PASSWORD`.

## Environment variables

See `.env.example` for required variables.

## Project principles

- `BookingRequest` is the system of record
- LLMs assist; they do not own state
- Every important action is logged
- Ingestion and worker paths must be idempotent
- TDD is the default development style
