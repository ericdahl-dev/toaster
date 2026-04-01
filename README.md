# Toaster

Toaster is a multi-tenant SaaS AI booking assistant for venue inquiries.
It connects to Gmail, ingests inbound booking emails, extracts structured
request data, tracks workflow state, drafts follow-up replies, and supports
human approval when automation is not safe.

## Repo layout

- `backend/` — Rails API backend
- `frontend/` — Next.js operator dashboard and inbox UI

## Local setup

This repo is managed with version managers:
- Ruby: RVM
- Node: NVM

Recommended versions:
- Ruby 3.3.6
- Node 22.22.1

### Backend

```bash
cd backend
rvm use 3.3.6
bundle install
bin/rails db:prepare
bundle exec rspec
bin/rails s
```

The backend uses PostgreSQL by default. For local development it uses the
Rails database config in `backend/config/database.yml`. To point it at Neon,
set `DATABASE_URL` for the pooled application connection. For migrations,
run commands with `DATABASE_URL` pointing at the direct connection.

### Frontend

```bash
cd frontend
nvm use 22.22.1
corepack enable
yarn install --immutable
yarn test
yarn dev
```

## CI

GitHub Actions runs backend specs and frontend tests on every push and pull
request.

## Current status

Issue #2 is the active foundation issue. It is now underway in branch
`feat/issue-2-foundation`.

## POC demo path

The current POC uses the agent mailbox path instead of Gmail OAuth.

1. Start the backend on port 3001:

```bash
cd backend
bin/rails db:prepare
PORT=3001 bin/rails s
```

2. Seed the repeatable demo data:

```bash
cd backend
bin/rails poc:seed_agent_mailbox_demo
```

3. Start the frontend in another shell (defaults to port 3000):

```bash
cd frontend
NEXT_PUBLIC_TOASTER_API_BASE_URL=http://localhost:3001 yarn dev
```

4. Open the operator inbox:

```text
http://localhost:3000/inbox
```

What you should see:
- one captured inbox message from `demo.lead@example.com`
- one linked booking request snapshot
- extracted event date, headcount, and budget in the request detail

## Project principles

- BookingRequest is the system of record
- LLMs assist; they do not own state
- Every important action is logged
- Ingestion and worker paths must be idempotent
- TDD is the default development style
