# ADR 0009: Inbox thread read models (product HTML vs ops JSON)

## Status

Accepted (2026-05-18). Depends on `ConversationThreading` ([#379](https://github.com/ericdahl-dev/toaster/issues/379)). Tracks [#380](https://github.com/ericdahl-dev/toaster/issues/380).

## Context

Operators use **ops JSON** grouped by `InboxMessage.provider_thread_id` (inbox-native / raw thread keys). Venue managers use **product HTML** at `/inbox_threads/:id` where `:id` is the `ConversationThread` database primary key. Persist stores `ConversationThread.provider_thread_id` as a canonical `provider:raw` value via `ConversationThreading`.

## Decision

1. **`InboxThreads::Read`** is the shared read model for thread detail payloads and ops booking lookups keyed by inbox-native thread id.
2. **`Ops::ThreadView`** remains a thin JSON adapter delegating to `InboxThreads::Read.detail`.
3. **Product HTML** continues to load `ConversationThread` by AR id; it does not accept inbox-native thread ids in URLs. Cross-surface links use booking request or ops params as appropriate.

## ID contract

| Surface | Parameter | Meaning |
|---------|-----------|---------|
| Ops list/show | `provider_thread_id` | Inbox-native thread id (matches `InboxMessage.provider_thread_id`) |
| Product show | `conversation_threads/:id` | `ConversationThread` primary key |
| Database | `conversation_threads.provider_thread_id` | Canonical `provider:inbox_thread_id` from `ConversationThreading` |

## Consequences

- Ops booking joins and thread detail timelines stay aligned with Persist output without manual factory alignment.
- Product thread UI can adopt `InboxThreads::Read` later if we add inbox-native routes; no change required for current Hotwire pages.
