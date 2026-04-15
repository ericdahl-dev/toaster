# Venue RAG Pipeline Plan (EDV-6)

## Purpose

Define a production-safe retrieval pipeline that lets booking-response drafting use venue knowledge while preventing cross-venue leakage.

## Scope and non-goals

### In scope

- Venue document sources and ingestion boundaries
- Parser/tooling decision (including `unstructured`)
- Chunking and metadata strategy
- Venue identification and retrieval scoping controls
- Evaluation plan and booking-flow integration

### Out of scope

- Final model selection for response generation
- UI design for operator editing
- Full migration of historical bookings

## Inputs and constraints

- Existing venue data model milestone output
- Venue-specific materials (example: Brando's event guide)
- Requirement: retrieval must disambiguate among many venues and must not leak details across venues

## Canonical entities

- `Venue`: canonical business entity (stable `venue_id`)
- `VenueAlias`: alternate names, abbreviations, old names, common misspellings
- `VenueDocument`: uploaded or fetched source file tied to one venue
- `VenueChunk`: retrievable chunk derived from one document section

Hard rule: every `VenueDocument` and `VenueChunk` must include one and only one `venue_id`.

## Source documents and ingestion boundaries

### Allowed source classes

1. Venue-owned docs (PDF/DOCX/HTML): event guides, menus, floor plans, policies
2. Structured venue records from internal data model (capacity, amenities, constraints)
3. Venue-scoped email attachments explicitly linked to that venue

### Excluded from retrieval corpus

- Cross-venue internal notes
- Unlinked inbox files without venue resolution
- Free-form operator drafts not promoted to canonical venue facts

## Tooling evaluation

## `unstructured` (recommended default parser)

Pros:

- Strong parsing for mixed formats and OCR-heavy files
- Fast path to reliable section/table extraction
- Less custom parsing maintenance

Cons:

- External dependency and parser-version drift risk
- Requires fallback path for parser outages or malformed files

Decision:

- Use `unstructured` as default partitioning + OCR layer.
- Preserve raw file and parser output for reproducibility.
- Keep chunking, metadata policy, embeddings, and retrieval in our backend.

### Fallback parser strategy

- Use lightweight local parser chain when `unstructured` fails:
  - text PDFs: `pdfplumber`/native extract
  - Office docs: text conversion pipeline
  - HTML: DOM section extraction
- Mark `parse_quality` and `parser_name` in metadata.
- Do not index chunks with `parse_quality=failed`.

## Ingestion pipeline design

1. **Acquire**
   - Receive file upload or synced source.
   - Create `VenueDocument` in `processing` state.
2. **Resolve venue**
   - Require explicit `venue_id` from upload context or resolver.
   - If confidence below threshold, move to `needs_review` (do not index).
3. **Parse**
   - Run `unstructured` partition/OCR.
   - Capture elements, page refs, tables, titles.
4. **Normalize**
   - Clean whitespace, remove boilerplate headers/footers.
   - Promote typed facts where possible (capacity, min spend, AV notes).
5. **Chunk**
   - Build semantically coherent chunks (details below).
6. **Embed + index**
   - Generate embeddings.
   - Upsert to vector store with strict metadata filters.
7. **Validate**
   - Run post-index checks (venue tag present, token size bounds, duplicate ratio).
8. **Publish**
   - Mark document `indexed` and emit ingestion audit event.

## Chunking strategy and retrieval boundaries

### Chunking policy

- Target size: 350-700 tokens
- Overlap: 50-90 tokens (section-aware)
- Never cross section headings during chunk merge
- Keep table rows grouped by table/subheading
- Preserve citation metadata: `document_id`, `page`, `section_path`

### Metadata schema (required fields)

- `venue_id` (hard filter key)
- `document_id`
- `source_type` (`guide`, `menu`, `policy`, `faq`, `email_attachment`, etc.)
- `section_path` (e.g., `pricing > saturday > buyout`)
- `effective_date` / `expires_at` (nullable)
- `parser_name`, `parse_quality`
- `fact_type` (optional typed category: `capacity`, `catering`, `a_v`, ...)
- `visibility` (`internal`, `customer_safe`)

### Retrieval boundaries

- All retrieval requests must include resolved `venue_id`.
- Vector query must use metadata filter `venue_id == <resolved_venue_id>`.
- Re-ranker input must be pre-filtered by same `venue_id`.
- Prompt assembler must reject chunks with mismatched `venue_id`.

## Venue identification and disambiguation

### Resolution flow

1. Prefer explicit venue from booking thread/account linkage.
2. If missing, run deterministic alias lookup (`VenueAlias`) with account constraints.
3. If still ambiguous, run classifier over top candidate venues.
4. Require confidence threshold (e.g., >= 0.90) to proceed automatically.
5. Otherwise escalate to operator and block retrieval.

### Anti-leakage controls

- **Control 1: hard metadata filter** at retriever
- **Control 2: prompt-time assertion** that all chunks match active `venue_id`
- **Control 3: response citation verifier** ensures every cited chunk belongs to active venue
- **Control 4: evaluation gate** fails deploy if cross-venue leakage exceeds threshold

## Booking-request flow integration

1. Booking request is parsed into structured record.
2. Venue resolver returns `venue_id` + confidence.
3. If confidence is low, route to manual review before drafting.
4. Retriever queries venue-scoped chunks and structured venue facts.
5. Context builder assembles:
   - top-k semantic chunks
   - typed facts from venue model
   - booking request constraints (date, party size, event type)
6. Draft response generated with required citations.
7. Operator reviews draft and can approve/edit/send.
8. Feedback loop captures corrections for eval set growth.

## Evaluation plan

### Offline evaluation sets

- **Venue disambiguation set**: similar names, aliases, and ambiguous references
- **Grounded QA set** per venue document
- **Leakage set**: prompts intentionally mixing two venues
- **Freshness set**: changed policy docs with old conflicting facts

### Metrics and gates

- Venue resolution accuracy
- Retrieval recall@k against labeled relevant chunks
- Citation precision (statement supported by cited chunk)
- Cross-venue leakage rate
- Hallucinated policy rate

Initial release gates (can tighten later):

- Leakage rate: 0 in must-pass leakage suite
- Citation precision: >= 0.95
- Venue resolution accuracy: >= 0.98 on curated ambiguous set

### Online monitoring

- % drafts requiring major operator correction
- Venue mismatch incident count
- Parse failure and `needs_review` rates
- Latency budget for retrieve + draft path

## Data model additions (minimal)

- `venue_aliases` table (or equivalent model)
- `venue_documents` ingestion state + provenance fields
- `venue_chunks` with immutable `venue_id` and citation metadata
- `ingestion_events` audit log for parser/index lifecycle

## Rollout plan

1. Implement ingestion + strict metadata filters.
2. Backfill one pilot venue corpus (including Brando's guide).
3. Run offline eval suite and fix leakage/grounding failures.
4. Enable drafting for pilot venues behind feature flag.
5. Expand to multi-venue cohorts after gate pass.

## Risks and mitigations

- Ambiguous venue names -> alias table + high-confidence gating + manual fallback
- Parser variance across document types -> parser metadata + fallback chain + quality checks
- Stale documents -> effective dates + periodic reindex jobs
- Overly broad chunks -> section-aware chunking + citation verifier

## Implementation checklist

- [ ] Finalize metadata schema and DB migration
- [ ] Build venue resolver with confidence output
- [ ] Integrate `unstructured` + fallback parser
- [ ] Implement chunker and embed/index worker
- [ ] Enforce venue-scoped filters in retriever and prompt assembler
- [ ] Add offline eval suites and CI gates
- [ ] Wire drafting endpoint to new context builder
- [ ] Add monitoring dashboards and incident alerts
