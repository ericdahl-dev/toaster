# ADR 0001: Post-ingestion booking via Reconcile (not Transition)

## Status

Accepted (2026-05-04)

## Context

Inbox sync (`InboxIngestion::Sync`) persists `InboxMessage` rows from IMAP and Agent Mailbox. `BookingRequests::Reconcile` runs extraction (`AgentMailbox::ExtractBookingRequest`), event logging, and review tasks. `BookingRequests::Transition` encodes allowed manual/API status changes.

## Decision

1. **Integrated:** After each successful upsert in `InboxIngestion::Sync`, call `BookingRequests::PostIngestion.after_inbox_message_persisted`, which delegates to `BookingRequests::Reconcile`. All ingestion adapters share this path (`SyncImapJob`, `SyncAgentMailboxJob`).

2. **Transition is out of scope for ingestion:** `BookingRequests::Transition` is only for explicit workflow (e.g. ops/API confirming or rejecting a request). It is not invoked automatically when mail lands.

## Consequences

- New or updated messages from sync refresh `BookingRequest` rows and audit logs on each upsert (including deduped updates in the same batch).
- Reconcile failures fail the sync job; the job can retry and reconcile again.
