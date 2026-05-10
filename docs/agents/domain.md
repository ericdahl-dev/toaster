# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — single shared domain glossary for the Rails API and Next.js frontend.
- **`docs/adr/`** at the repo root — read ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront.

## File structure

Single-context repo:

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-post-ingestion-booking-reconcile.md
│   ├── 0002-multi-venue-mail-routing.md
│   ├── 0003-goodjob-replaces-solid-queue.md
│   ├── 0004-rails-hotwire-monolith-replaces-nextjs.md
│   ├── 0005-dark-industrial-design-system.md
│   ├── 0006-agentmail-removed-imap-only.md
│   └── 0007-role-based-access-control.md
└── app/          # Rails 8.0 (root-level, moved from backend/ in #135)
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

Key terms: **inbox message**, **inbox ingestion**, **provider**, **checkpoint**, **ingestion adapter**, **booking request**, **extraction lock**, **venue**, **mail connection**, **user**, **account**.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/grill-with-docs`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0001 (post-ingestion booking reconcile) — but worth reopening because…_
