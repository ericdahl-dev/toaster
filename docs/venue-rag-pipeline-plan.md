# Venue RAG Pipeline Plan (EDV-6)

## 1) Goal and safety bar

Design a venue-specific retrieval pipeline that lets booking-response drafting use:

- **Structured venue data** (canonical fields from the venue model), and
- **Unstructured venue documents** (guides, FAQs, policies, floor plans, menus)

while guaranteeing we do not leak details across venues.

### Success criteria

1. The system resolves the intended venue with high confidence before retrieval.
2. Retrieval is hard-scoped to that venue only (`venue_id` boundary).
3. Draft responses are grounded in retrieved evidence and canonical fields.
4. If confidence is low, the flow asks a clarifying question instead of guessing.

## 2) Source documents and ingestion boundaries

## In-scope sources

- Venue-uploaded PDFs, DOCX, TXT, Markdown files.
- Web pages explicitly mapped to a venue (venue website pages, event guide pages).
- Internal structured venue fields transformed into retrievable “facts” documents.
- Versioned policy docs (capacity, curfew, load-in/out, AV, catering, cancellation terms).

## Out-of-scope sources (initial launch)

- Cross-venue “global tips” docs unless tagged as reusable templates.
- Email threads and ad hoc chat logs.
- Unverified third-party content without explicit venue ownership.

## Ingestion boundary rules

Every ingested artifact must include:

- `tenant_id`
- `venue_id`
- `source_type` (`upload`, `web`, `structured_fact`, etc.)
- `source_uri` (or immutable document id)
- `version` (content hash / revision id)
- `effective_at` and optional `expires_at`

Artifacts without a valid `venue_id` are rejected at ingest time.

## 3) Parsing and ingestion tooling decision

## Primary parser: `unstructured`

Use `unstructured` as default for broad file coverage and layout-aware extraction:

- Good handling for PDFs and DOCX.
- Element-level outputs useful for chunking by logical sections.
- Supports metadata propagation during extraction.

## Fallback parser strategy

Implement parser fallback chain when quality thresholds fail:

1. `unstructured` (default)
2. format-specific parser (e.g., `pypdf` text extraction for problematic PDFs)
3. OCR-enabled path for scanned docs only

Track parser outcomes with:

- extraction success/failure
- character count and section count
- quality flags (e.g., low text density, repeated garbage patterns)

Documents that fail minimum extraction quality are quarantined for manual review.

## 4) Chunking strategy and retrieval boundaries

## Chunking policy

- Chunk by semantic sections first (headings/blocks), not fixed windows alone.
- Target size: ~400-800 tokens, with 10-15% overlap for continuity.
- Preserve table/list structures where possible.
- Attach section title and page/element references.

## Chunk metadata schema (required)

Each chunk stores:

- `chunk_id`
- `tenant_id`
- `venue_id`
- `document_id`
- `document_version`
- `source_type`
- `title`
- `section_path` (e.g., `Event Guide > Catering > Bar Packages`)
- `page_span` (if applicable)
- `effective_at`, `expires_at`
- `sensitivity` (public/internal/restricted)
- `embedding_model`
- `ingested_at`

## Hard retrieval boundaries

Retrieval query must include hard filters:

- `tenant_id = X`
- `venue_id = Y`
- `effective_at <= now < expires_at` (if set)
- `sensitivity` allowed by requesting context

Do **not** rely on semantic similarity alone for venue isolation.

## 5) Venue identification and disambiguation flow

## Inputs used for venue resolution

- Explicit venue id in booking request context (preferred).
- Venue name aliases / normalized string matching.
- Structured hints: city, state, neighborhood, account ownership, prior thread context.

## Resolution algorithm

1. If explicit `venue_id` is present and authorized, use it directly.
2. Else run candidate generation via alias + fuzzy match.
3. Re-rank candidates with contextual hints.
4. Compute confidence score.

## Confidence gating

- **High confidence**: proceed to retrieval.
- **Medium/low confidence**: ask user a clarifying question with top candidates.
- **No valid candidate**: return safe fallback (“I need the venue name/location to continue”).

No retrieval happens until a single venue is selected.

## 6) Anti-leakage controls

1. **Index partitioning:** logical partition key includes `tenant_id` and `venue_id`.
2. **Query-time filters:** mandatory server-side filters (non-optional).
3. **Post-retrieval validator:** drop chunks with mismatched venue metadata.
4. **Prompt guardrails:** include selected venue identity and forbid cross-venue facts.
5. **Citation checks:** final draft must cite chunks whose `venue_id` matches selected venue.

If validator removes all chunks, the flow must ask for clarification or degrade gracefully.

## 7) Booking-request flow integration

## Proposed request path

1. Intake booking request.
2. Resolve venue (or ask clarification).
3. Pull canonical structured venue fields from venue model.
4. Retrieve top-k venue-scoped chunks from vector store.
5. Re-rank and dedupe chunks; keep concise evidence set.
6. Generate response draft with:
   - structured facts first,
   - retrieved details second,
   - citations to source chunks.
7. Run safety checks (venue match, confidence, unsupported-claim detector).
8. Return draft response or clarification prompt.

## Minimal data model additions

- `venue_document` table/entity with ownership + versioning metadata.
- `venue_document_chunk` with chunk text + metadata schema above.
- `venue_alias` mapping table for disambiguation.
- Optional `retrieval_audit_log` for evaluation and incident review.

## 8) Evaluation plan

## Offline eval set

Build a gold dataset from real venue docs and booking prompts:

- Venue-disambiguation cases (similar names, same city, same tenant).
- Cross-venue leakage traps (intentionally overlapping topics).
- Time-scoped policy cases (old vs current versions).
- Unanswerable queries requiring clarification.

## Key metrics

- Venue resolution accuracy.
- Retrieval precision@k (venue-correct and answer-relevant).
- Leakage rate (any cited chunk with wrong `venue_id`).
- Groundedness/citation coverage.
- Clarification rate when confidence below threshold.

## Release gates

Block rollout unless:

- leakage rate == 0 on eval set,
- venue resolution meets target threshold,
- groundedness exceeds minimum threshold.

## Online monitoring

- Log resolved `venue_id`, candidate list, confidence, retrieved chunk ids.
- Sample and review drafts for leakage/grounding weekly.
- Add regressions to eval suite before model/pipeline changes.

## 9) Rollout phases

1. **Phase 0 (plan + schema):** implement document/chunk metadata model and ingest contracts.
2. **Phase 1 (single-venue pilot):** one tenant, strict guards, manual QA.
3. **Phase 2 (multi-venue):** enable disambiguation + confidence prompting.
4. **Phase 3 (production hardening):** monitoring, incident playbooks, eval automation.

## 10) Open decisions to finalize during implementation

- Final embedding model and re-ranker choice.
- Vector store choice and partition strategy details.
- Exact confidence thresholds for auto-select vs clarification.
- OCR budget and limits for low-quality scans.

