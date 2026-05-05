# ADR 0002: Multi-venue mail routing, inbox lineage, and dedupe

## Status

Accepted (2026-05-05)

## Context

Operators manage multiple **venues** under one **Account**. **Mail connections** are account-scoped; **inbox messages** are account-scoped and uniquely keyed by `(account_id, provider, provider_message_id)`.

Some venues may share a mailbox (one connection, many logical inboxes via aliases or a single address). To treat **booking requests** as venue-specific, the system must know which venue an **inbox message** belongs to—or that it is ambiguous and needs human review.

Today:

- **Inbox messages** do not reference the **connection** that fetched them.
- Normalized `to_emails` exist on **inbox messages** but are not used to set `booking_requests.venue_id`.
- The same logical message could theoretically be ingested via two connections; the unique index collapses them to one row per account and provider message id.

## Decision

1. **Lineage:** Persist provenance from **inbox ingestion** to **inbox messages**—which **mail connection** produced or last updated the row (for example polymorphic `source_connection` or provider-specific nullable foreign keys). Adapters and jobs already know the connection; storage should reflect it for routing, debugging, and permissions.

2. **Venue routing rules:** Introduce an explicit, ordered mechanism to map an **inbox message** to zero or one **venue** (examples: normalized match on `to_emails`, IMAP folder, AgentMailbox metadata, subject prefix). Evaluation runs during or immediately after upsert, before or inside **reconcile**, so `booking_requests.venue_id` can be set consistently. Unmatched or conflicting matches should land in **reviewing** (or a dedicated status/reason), not silent wrong-venue assignment.

3. **Dedupe across connections:** When the same provider message id could appear from two **connections**, document and implement one strategy: prefer a single row with deterministic “winning” lineage updates, **or** change the uniqueness key if product requires one row per connection. The choice must align with how **checkpoint**s and support tooling reason about duplicates.

## Consequences

- Schema and ingestion paths gain connection linkage; migrations and backfill may be required for historical rows.
- Routing rule configuration (and tests) becomes part of the operator setup story for multi-venue accounts.
- **Reconcile** and extraction can depend on a resolved `venue_id` without guessing from free text alone.
