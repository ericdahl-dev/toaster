# Toaster (backend inbox)

Toaster ingests email from connected inboxes, persists normalized rows for downstream booking workflows, and keeps each connection’s incremental fetch position accurate.

## Language

**Inbox message**:
A single persisted message row for one account, identified by provider plus provider-assigned message id.

**Inbox ingestion**:
The process of fetching new messages from a connected inbox, upserting inbox messages, and advancing that connection’s checkpoint. The shared orchestrator is `InboxIngestion::Sync`; each provider supplies an **ingestion adapter** for fetch and checkpoint semantics.

**Provider**:
The system that holds the mailbox (for example IMAP or AgentMailbox). Each provider has its own wire protocol and checkpoint shape.

**Checkpoint**:
Where incremental ingestion resumes for a connection. Meaning is provider-specific (for example UID versus wall-clock time); the ingestion orchestrator does not assume a single storage shape. After each ingestion run, the orchestrator always asks the adapter to commit checkpoints **even when no messages arrived**; whether that updates storage is adapter-specific (for example wall-clock cursors may advance on empty runs; UID cursors may not).

**Ingestion adapter**:
The provider-owned object that implements fetch and checkpoint read/write for one connection. Adapters live alongside the shared ingestion orchestrator under `app/services/inbox_ingestion/` and delegate wire-protocol work to existing fetcher modules.

## Relationships

- An **Account** has one or more inbox **connections** (per provider).
- **Inbox ingestion** produces or updates **inbox messages** scoped to that **account**.
- Each **connection** owns at most one active **checkpoint** semantics for its **provider**.

## Access and identity

- **User** (app user): a person who signs in to Toaster with **Toaster credentials** (email and password). A user belongs to exactly one **Account** for now; session-backed APIs resolve the tenant from that membership.
- **Toaster sign-in email** is only for authentication. It is unrelated to the addresses or credentials stored on **connections** (IMAP username/host, AgentMailbox inbox identifiers, and so on).
- API calls that include another account’s id while signed in are **not** treated as “missing data”; they are rejected as **forbidden** (HTTP 403) to signal authorization failure clearly.
- Self-service **sign-up** (creating a new tenant or user without an operator) is a separate product slice from **sign-in**; until that exists, users are provisioned through normal operator/setup flows.

## Example dialogue

> **Dev:** "After we unify ingestion, does every provider use the same checkpoint column?"
> **Domain expert:** "No. IMAP thinks in server UIDs; AgentMailbox thinks in API `after` time. The shared path only cares that the adapter advances the right cursor for that provider."

## Flagged ambiguities

- "Sync" was used for both job enqueue and ingestion orchestration — resolved: **inbox ingestion** is the orchestrated fetch+upsert+checkpoint step; jobs remain thin schedulers.
- Fetch and transport failures during ingestion **bubble** to the job layer so retries and monitoring stay consistent; ingestion does not convert hard failures into silent partial success.
