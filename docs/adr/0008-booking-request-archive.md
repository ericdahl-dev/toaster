# ADR 0008: Booking request archive (list hygiene separate from status)

## Status

Accepted (2026-05-18). Domain glossary: `CONTEXT.md` (**Archive**). Tracks [#369](https://github.com/ericdahl-dev/toaster/issues/369).

## Context

The **booking requests** index shows every row for the account, ordered by `updated_at`. Workflow **status** includes terminal `cancelled`, but cancelled rows still clutter the default queue. Operators need to clear the main list without deleting history (messages, drafts, **event log**, **AiRun** rows).

`BookingRequests::Persist` reuses `thread.booking_requests.first` on each reconcile, so a thread typically has one active **booking request** row that keeps receiving extraction updates when mail arrives.

## Decision

1. **Archive is not a status.** Persist visibility with `archived_at` (nullable timestamp). Default index scope excludes `archived_at IS NOT NULL`. **Transition** and **status** are unchanged.

2. **Orthogonal to `cancelled`.** Any status may be archived; `cancelled` does not auto-archive. Operators archive and cancel independently.

3. **Unarchive on new inbound.** When reconcile runs for a **newly upserted** inbound **inbox message** on the same **conversation thread** (`inbox_message_created: true` from `InboxIngestion::Sync`), clear `archived_at` on that thread's booking request. Deduped re-sync of an existing inbox row does not unarchive. Reconcile and draft generation continue while archived; only the default list hides the row.

4. **Operator surfaces.** Archive from detail or index row (confirm before archive; stronger copy if a `pending_review` **draft** or open review **task** exists). Unarchive from detail or index with **show archived** on. Same access as **transition** (any account **user**). See `CONTEXT.md` for inbox-thread badge behavior.

5. **Audit and telemetry.** Append **event log** entries for archive, manual unarchive, and auto-unarchive. PostHog: `booking_request_archived` and `booking_request_unarchived` with `source: manual | inbound`.

## Considered options

| Option | Why not (for v1) |
|--------|------------------|
| Hide via `cancelled` only | Conflates deal outcome with inbox hygiene; cancelled rows still need explicit hide |
| Freeze reconcile while archived | Real follow-ups would stay stale until someone remembers to unarchive |
| Silent update while archived | Operators lose signal that mail arrived; inbox thread helps but auto-unarchive is clearer |
| New **booking request** per thread reply | Fights `Persist`'s `thread.booking_requests.first`; multi-request threads are future work (ADR 0001) |
| Hard delete | Destroys audit trail and complicates support |

## Consequences

- Implementation adds `archived_at`, `BookingRequests::Archive` / `Unarchive` services, controller actions, index toggle, and inbox-thread badge for archived primary requests.
- Spam archived then auto-unarchived by an auto-reply is possible; mitigated by operator re-archive and confirm copy—not by blocking reconcile.
- **Extraction lock** (terminal status skipping re-extraction) remains a separate, not-yet-enforced glossary rule; archive does not replace it.
