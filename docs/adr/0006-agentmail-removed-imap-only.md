# ADR 0006: AgentMail removed; IMAP is the sole inbox provider

## Status

Accepted (2026-05-09)

## Context

Toaster initially supported two inbox providers: IMAP (`ImapConnection`) and AgentMail (`AgentmailConnection`). AgentMail is a managed inbox API that abstracts SMTP/IMAP behind a webhook and REST surface.

In practice:
- The customer POC ran entirely over Gmail/IMAP.
- AgentMail connections were never exercised in production or the POC.
- Maintaining two ingestion adapters doubled the surface area for the provider-agnostic ingestion layer without delivering any active use case.
- The `InboxIngestion::Sync` orchestrator already abstracts provider differences behind an adapter contract — adding a new provider later is a well-defined extension point.

## Decision

Drop `AgentmailConnection` and its ingestion adapter. IMAP (`ImapConnection`) is the only supported inbox provider. The `InboxIngestion::AdapterContract` and the shared orchestrator remain in place so a future provider (e.g. a webhook-based API, Microsoft Graph, or a new managed inbox service) can be added as a new adapter without touching the orchestrator.

## Consequences

- `agentmail_connections` table dropped; migration is irreversible without the `down` method.
- References to AgentMail removed from routes, jobs, and services.
- CONTEXT.md and ADR 0002 updated to remove AgentMail as a provider example.
- Any future second provider must implement `InboxIngestion::AdapterContract` and register a corresponding job.
