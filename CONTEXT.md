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
Where incremental ingestion resumes for a connection. Meaning is provider-specific (for example UID versus wall-clock time); the ingestion orchestrator does not assume a single storage shape. After each ingestion run, the orchestrator always asks the adapter to commit checkpoints **even when no messages arrived**; whether that updates storage is adapter-specific (for example wall-clock cursors may advance on empty runs; UID cursors may not). For IMAP, the first sync on a new connection imports only the last seven days (`Imap::Fetcher::INITIAL_SYNC_WINDOW`); older mail is skipped until a deliberate backfill exists. If that window is empty, the checkpoint still advances to the mailbox’s highest UID so later syncs only fetch new mail.

**Ingestion adapter**:
The provider-owned object that implements fetch and checkpoint read/write for one connection. Adapters live alongside the shared ingestion orchestrator under `app/services/inbox_ingestion/` and delegate wire-protocol work to existing fetcher modules.

**Booking request**:
A persisted row derived from an **inbox message** for venue/event intake; extraction fills structured fields and a status. Orchestrated by **reconcile** after each inbox message upsert (see `docs/adr/0001-post-ingestion-booking-reconcile.md`).

**Extraction lock**:
When a booking request's status is **confirmed** or **cancelled**, further **inbox ingestion** records inbound **messages** but does not re-run the classifier, LLM extraction, draft generation, or review tasks. Human workflow outcomes via **transition** stay authoritative until status returns to **pending** or **reviewing**. Reconcile logs `booking_request.inbound_recorded` instead of `booking_request.updated`. **Archive** does not bypass the lock.

**Venue**:
A bookable location managed by an **Account**. **Booking requests** may reference a venue (`venue_id` optional). Venues are not tied to a single mail **connection** in the schema today. Venues carry a `features` jsonb array (e.g. `["karaoke", "coat_check", "parking"]`) listing venue-wide amenities — operator-defined free-form strings used by the AI to ask relevant questions.

**Venue space**:
A named bookable area within a **Venue** (e.g. "East Room", "Rooftop", "Full Buyout"). Stores structured capacity and pricing data used by the AI pipeline for fit routing: `capacity_seated`, `capacity_reception`, `min_guests`, `max_guests`, `pricing_floor_cents`. Also carries intake metadata: `duration_options` (jsonb array of offered durations, e.g. `["2_hours", "all_night"]`), `private` (boolean, default false — whether the space is fully private), `features` (jsonb array of space-specific amenities, e.g. `["private_bar", "stage"]`). One venue has many spaces. Space and feature strings are operator-defined free text — no standard set enforced.

**Venue knowledge**:
Two-layer model. Layer 1 (structured): `VenueSpace` DB fields for headcount fit and pricing floor checks — queryable, used by AI decisioning. Layer 2 (unstructured): the full event guide (pricing matrices, bar tiers, package inclusions, policies) embedded into a per-venue PGVector store via Unstructured.io. The AI uses RAG against Layer 2 for detailed question answering and quote drafting.

**Mail connection**:
Credentials plus checkpoint state for one mailbox on a **provider** (currently IMAP only via `ImapConnection`; AgentMail was removed in May 2026 — see ADR 0006). Belongs to an **Account**, not to a specific **Venue**.

**Inbox filter**:
A keyword→venue mapping scoped to a **mail connection**. When an inbox message arrives on a connection, the ingestion adapter evaluates filters in insertion order (ascending `priority`) and assigns the first matching **venue** to the resulting **booking request**. Filters are case-insensitive substring matches against the message subject. No match leaves `venue_id` nil. Filters belong to the connection, not the venue — one venue may appear in filters on multiple connections.

**Transition**:
A deliberate operator action that moves a **booking request** through its lifecycle. Valid paths: `pending → reviewing`, `pending → confirmed`, `pending → cancelled`; `reviewing → pending`, `reviewing → confirmed`, `reviewing → cancelled`; `confirmed → cancelled`. Transitions are initiated from the booking request detail page via contextual buttons that reflect the current state. Transitions outside these paths are rejected.

**Archive**:
A deliberate operator action that removes a **booking request** from the default **booking requests** list without deleting the row or changing workflow **status**. See `docs/adr/0008-booking-request-archive.md`. Operators may **archive** at any workflow **status** (open **tasks** and `pending_review` **drafts** are not cleared); from the detail page or a per-row control on the index, with a confirmation step before archive—and stronger confirmation copy when a draft or task is still open; they may **unarchive** from detail or from the index while **show archived** is on, without confirmation. Archived requests remain reachable via a **show archived** toggle on the same **booking requests** index (off by default) and can be **unarchived** manually from there or from detail. Archive is orthogonal to **transition**: any status may be archived or left visible, and `cancelled` does not imply archived (no auto-archive on cancel). **Unarchive on new inbound**: when a newly ingested inbound **inbox message** arrives on the same **conversation thread** (not a deduped re-sync), the archived **booking request** is automatically unarchived so it reappears on the default list. Any signed-in **user** on the **account** may **archive** or **unarchive** (same access as **transition**). On the **inbox threads** list, a thread whose primary **booking request** is archived remains visible; its status column shows **archived** (not only workflow **status**).

**Event log**:
An append-only audit trail of all significant state changes and external interactions on a **booking request** — including job activity (sync, reconcile, push) and human actions (transitions, draft approve/reject, **archive**, **unarchive**). Manual and automatic **unarchive on new inbound** both produce log entries. Rendered read-only in chronological order on the booking request detail page.



- An **Account** has one or more inbox **connections** (per provider).
- An **Account** has one or more **venues**.
- Each **venue** has zero or more **venue spaces**.
- **Inbox ingestion** produces or updates **inbox messages** scoped to that **account**.
- Each **connection** owns at most one active **checkpoint** semantics for its **provider**.

## Access and identity

- **Authentication**: Toaster uses **Devise** (`devise_for :users`). Custom Devise views live in `app/views/users/`. The `sessions_controller.rb` is a thin Devise subclass. There is **no hand-rolled auth** — do not use `has_secure_password` or custom session logic.
- **User** (app user): a person who signs in to Toaster with **Toaster credentials** (email and password). A user belongs to exactly one **Account** and carries a **role**: `admin` or `venue_manager` (default). Admins can create accounts and users; venue managers access booking workflows only. See ADR 0007.
- **Toaster sign-in email** is only for authentication. It is unrelated to the addresses or credentials stored on **connections** (IMAP username/host and so on).
- API calls that include another account's id while signed in are **not** treated as "missing data"; they are rejected as **forbidden** (HTTP 403) to signal authorization failure clearly.
- Self-service **sign-up** (creating a new tenant or user without an admin) does not exist — admins provision accounts and users through `/admin/accounts/new` and `/admin/users/new`.

## Example dialogue

> **Dev:** "After we unify ingestion, does every provider use the same checkpoint column?"
> **Domain expert:** "No. IMAP thinks in server UIDs. The shared path only cares that the adapter advances the right cursor for that provider."

**Classifier**:
A cheap, fast LLM call (gpt-4o-mini, structured output `{ booking_request: boolean }`) that runs as the first step inside `BookingRequests::Extract`. Non-booking emails (auto-replies, out-of-office, noise) are filtered here — no `BookingRequest` row is created for them. Each classifier call is persisted as an `AiRun` with `run_type: "classifier"`.

**LLM extraction**:
Replaces `FieldExtractor` (regex-based). `BookingRequests::LlmExtractor` calls OpenAI with structured output and produces: `event_date`, `headcount`, `budget` (dollars, not cents), `start_time`, `celebration_type`, `confidence`, `notes`. Each call is persisted as an `AiRun` with `run_type: "extraction"`. Raises `ConfigurationError` when `OPENAI_API_KEY` is absent.

**Budget**:
A rough dollar estimate from an inbound email — stored as a decimal on `BookingRequest` (column: `budget`). Not cents. Not a financial transaction amount.

**Validate-before-apply**:
`BookingRequests::ValidateExtraction` — normalizes raw LLM output, computes derived fields (`fit_status`, `staff_summary`, `missing_fields`), and reads `VenueSpace` records for fit logic. Pure Ruby, no LLM calls. Runs after `LlmExtractor`, before any `BookingRequest` write.

**Fit status**:
Computed by `ValidateExtraction` using the booking request's venue's `VenueSpace` records. Values: `qualified`, `not_a_fit`, `in_progress`. Nil when no venue is assigned. Stored on `BookingRequest`.

**Decisioner**:
`BookingRequests::Decisioner` — pure function that maps a validated extraction result to a `BookingRequest` status (`pending` or `reviewing`). Routes to `reviewing` on: any missing required fields, `fit_status: not_a_fit`, or `confidence < CONFIDENCE_THRESHOLD (0.8)`.

**Email body stripping**:
`EmailBody::Strip` — standalone string→string service that removes quoted reply headers, original message blocks, and signatures from raw email body text before any LLM call. Called in `BookingRequests::Extract` before the classifier and extractor run.

**AiRun**:
Persisted record of one LLM call: `run_type` (`classifier` | `extraction`), `llm_model`, `prompt`, `prompt_version`, `response`, `input_tokens`, `output_tokens`, `latency_ms`. Belongs to `Account` and optionally to `BookingRequest`. Every classifier and extraction call produces one `AiRun`.

## Flagged ambiguities

- "Sync" was used for both job enqueue and ingestion orchestration — resolved: **inbox ingestion** is the orchestrated fetch+upsert+checkpoint step; jobs remain thin schedulers.
- Fetch and transport failures during ingestion **bubble** to the job layer so retries and monitoring stay consistent; ingestion does not convert hard failures into silent partial success.
- **Multi-venue mail routing:** Resolved via **inbox filters**. Each `ImapConnection` carries keyword-based `InboxFilter` rules that match subject lines and assign a `venue_id`, removing the need for `To:` address or folder heuristics. See `docs/adr/0002-multi-venue-mail-routing.md`.
