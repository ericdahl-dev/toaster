# ADR 0001: Post-ingestion booking via Reconcile (not Transition)

## Status

Accepted (2026-05-04)

## Context

Inbox sync (`InboxIngestion::Sync`) persists `InboxMessage` rows from IMAP. `BookingRequests::Reconcile` runs extraction, event logging, and review tasks. `BookingRequests::Transition` encodes allowed manual/API status changes.

## Decision

1. **Integrated:** After each successful upsert in `InboxIngestion::Sync`, call `BookingRequests::Reconcile`. All ingestion adapters share this path (`SyncImapJob`).

2. **Transition is out of scope for ingestion:** `BookingRequests::Transition` is only for explicit workflow (e.g. ops/API confirming or rejecting a request). It is not invoked automatically when mail lands.

## Consequences

- New or updated messages from sync refresh `BookingRequest` rows and audit logs on each upsert (including deduped updates in the same batch).
- Reconcile failures fail the sync job; the job can retry and reconcile again.

## Amendment: multi-turn conversation context (2026-05-10)

A booking request routinely spans multiple email round-trips. Customers reply with additional details (dates, guest counts, catering requirements) across several messages before a request is fully resolved.

**Conversation history for AI drafts** is assembled per booking request from:

- `booking_request.messages` where `direction: :inbound` → role `"user"` turns
- `booking_request.drafts` where `status` in `%w[approved modified sent]` → role `"assistant"` turns

Messages are sorted by timestamp and passed to `DraftWriter` as an ordered `thread_history` array. `DraftWriter#call_openai` builds a full role-based OpenAI chat messages array: `system` prompt + history turns + final `user` turn.

**Scope note:** history is scoped to `booking_request`, not `conversation_thread`. A `ConversationThread` may eventually contain multiple booking requests (e.g. repeat inquiries from the same sender), but AI context is intentionally bounded to the single request being worked on. This can be revisited if multi-request thread context becomes valuable.

**Excluded from AI history:** `pending_review` and `rejected` drafts — only turns that were actually sent or approved by a human are treated as part of the conversation.
