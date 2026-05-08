# GoodJob replaces Solid Queue as the background job queue

Solid Queue is Rails 8's default Postgres-backed job queue, but it requires Sprockets and a separate Mission Control engine for its dashboard — an integration that caused asset pipeline friction in this API-only app (see the `sprockets-rails` workaround in AGENTS.md). GoodJob provides equivalent Postgres-backed, Redis-free operation with a dashboard that mounts directly as a Rails engine with no asset pipeline dependencies. Production runs a separate `bundle exec good_job start` worker process; development runs async inside Puma.

## Considered options

- **Keep Solid Queue + Mission Control** — Rails default, but the dashboard asset wiring was already a known pain point and would worsen as the app moves to a full-stack monolith.
- **GoodJob (chosen)** — same Postgres-only operational profile, better dashboard ergonomics, proven in the companion voice-assistant project.
