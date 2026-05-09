# Toaster (backend inbox)

Toaster ingests email from connected inboxes, persists normalized rows for downstream booking workflows, and keeps each connection's incremental fetch position accurate.

## Language

**Inbox message**:
A single persisted message row for one account, identified by provider plus provider-assigned message id.

**Inbox ingestion**:
The process of fetching new messages from a connected inbox, upserting inbox messages, and advancing that connection's checkpoint. The shared orchestrator is `InboxIngestion::Sync`; each provider supplies an **ingestion adapter** for fetch and checkpoint semantics.

**Provider**:
The system that holds the mailbox (currently IMAP only; see ADR 0006). Each provider has its own wire protocol and checkpoint shape.

**Checkpoint**:
Where incremental ingestion resumes for a connection. Meaning is provider-specific (for example UID versus wall-clock time); the ingestion orchestrator does not assume a single storage shape. After each ingestion run, the orchestrator always asks the adapter to commit checkpoints **even when no messages arrived**; whether that updates storage is adapter-specific (for example wall-clock cursors may advance on empty runs; UID cursors may not).

**Ingestion adapter**:
The provider-owned object that implements fetch and checkpoint read/write for one connection. Adapters live alongside the shared ingestion orchestrator under `app/services/inbox_ingestion/` and delegate wire-protocol work to existing fetcher modules.

**Booking request**:
A persisted row derived from an **inbox message** for venue/event intake; extraction fills structured fields and a status. Orchestrated by **reconcile** after each inbox message upsert (see `docs/adr/0001-post-ingestion-booking-reconcile.md`).

**Extraction lock**:
When a booking request's status is **confirmed**, **rejected**, or **cancelled**, further **inbox ingestion** does not re-run extraction on that message—human workflow outcomes stay authoritative until someone changes status again via **transition**.

**Venue**:
A bookable location managed by an **Account**. **Booking requests** may reference a venue (`venue_id` optional). Venues are not tied to a single mail **connection** in the schema today.

**Venue space**:
A named bookable area within a **Venue** (e.g. "East Room", "Rooftop", "Full Buyout"). Stores structured capacity and pricing data used by the AI pipeline for fit routing: `capacity_seated`, `capacity_reception`, `min_guests`, `pricing_floor_cents`. One venue has many spaces. Space names are operator-defined free text — no standard set enforced.

**Venue knowledge**:
Two-layer model. Layer 1 (structured): `VenueSpace` DB fields for headcount fit and pricing floor checks — queryable, used by AI decisioning. Layer 2 (unstructured): the full event guide (pricing matrices, bar tiers, package inclusions, policies) embedded into a per-venue PGVector store via Unstructured.io. The AI uses RAG against Layer 2 for detailed question answering and quote drafting.

**Mail connection**:
Credentials plus checkpoint state for one mailbox on a **provider** (currently IMAP only via `ImapConnection`; AgentMail was removed in May 2026 — see ADR 0006). Belongs to an **Account**, not to a specific **Venue**.

**Inbox filter**:
A keyword→venue mapping scoped to a **mail connection**. When an inbox message arrives on a connection, the ingestion adapter evaluates filters in insertion order (ascending `priority`) and assigns the first matching **venue** to the resulting **booking request**. Filters are case-insensitive substring matches against the message subject. No match leaves `venue_id` nil. Filters belong to the connection, not the venue — one venue may appear in filters on multiple connections.

**Transition**:
A deliberate operator action that moves a **booking request** through its lifecycle. Valid paths: `pending → reviewing`; `reviewing → confirmed`, `reviewing → rejected`, `reviewing → cancelled`. Transitions are initiated from the booking request detail page via contextual buttons that reflect the current state. Transitions outside these paths are rejected.

**Event log**:
An append-only audit trail of all significant state changes and external interactions on a **booking request** — including job activity (sync, reconcile, push) and human actions (transitions, draft approve/reject). Rendered read-only in chronological order on the booking request detail page.



- An **Account** has one or more inbox **connections** (per provider).
- An **Account** has one or more **venues**.
- Each **venue** has zero or more **venue spaces**.
- **Inbox ingestion** produces or updates **inbox messages** scoped to that **account**.
- Each **connection** owns at most one active **checkpoint** semantics for its **provider**.

**Prospect**:
A person who has expressed interest in Toaster by submitting their email via the waitlist form, but has not yet been provisioned as a **User** on an **Account**. A prospect has no login, no account, and no access to the application. Prospects are stored as `WaitlistEntry` rows with `email`, `company_name`, and `full_name`. A prospect becomes a **User** (venue manager) only when an **admin** explicitly invites them via `/admin/waitlist/:id/invite`, which creates the **Account** and **User** in a single transaction and marks `invited_at` on the `WaitlistEntry`.

## Access and identity

- **Account**: The company or group that has contracted with Toaster to use the platform. An account owns one or more **venues** and one or more **users** (venue managers). Accounts are provisioned by **admins**. Example: "Hubbard Inn" is an account; its venues ("Main Bar", "Rooftop") belong to it.
- **Venue manager** (role: `venue_manager`): A **user** who belongs to a customer **account** and logs in to manage that account's booking workflows. This is the primary operator persona — the person actually running the venue day-to-day.
- **Admin** (role: `admin`): A **user** who manages the Toaster platform itself — provisioning accounts, inviting prospects, and overseeing operations. Admins belong to the internal **"Toaster" account** (seeded in production). Admins are Toaster staff, not venue operators.
- **Toaster account**: The internal platform account (name: "Toaster") that all admin users belong to. There is exactly one Toaster account per deployment. It is seeded automatically and never appears in customer-facing views.
- **User**: Any person who signs in to Toaster with email and password. Every user belongs to exactly one **account** and carries one **role** — either `admin` or `venue_manager`. The term "user" alone is ambiguous; prefer **venue manager** or **admin** when the role matters.
- **Toaster sign-in email** is only for authentication. It is unrelated to the addresses or credentials stored on **connections** (IMAP username/host and so on).
- API calls that include another account's id while signed in are **not** treated as "missing data"; they are rejected as **forbidden** (HTTP 403) to signal authorization failure clearly.
- Self-service **sign-up** (creating a new tenant or user without an admin) does not exist — admins provision accounts and users through `/admin/accounts/new` and `/admin/users/new`. Token-gated onboarding links (from a waitlist invite) are permitted; anonymous self-signup is not.

## Example dialogue

> **Dev:** "After we unify ingestion, does every provider use the same checkpoint column?"
> **Domain expert:** "No. IMAP thinks in server UIDs. The shared path only cares that the adapter advances the right cursor for that provider."

## Flagged ambiguities

- "Sync" was used for both job enqueue and ingestion orchestration — resolved: **inbox ingestion** is the orchestrated fetch+upsert+checkpoint step; jobs remain thin schedulers.
- Fetch and transport failures during ingestion **bubble** to the job layer so retries and monitoring stay consistent; ingestion does not convert hard failures into silent partial success.
- **Multi-venue mail routing:** Resolved via **inbox filters**. Each `ImapConnection` carries keyword-based `InboxFilter` rules that match subject lines and assign a `venue_id`, removing the need for `To:` address or folder heuristics. See `docs/adr/0002-multi-venue-mail-routing.md`.
