# Toaster RAG Pipeline

This document sketches the proposed document-ingestion and retrieval architecture for Toaster.

## Goal

Turn messy venue source material into structured, retrievable knowledge that can support booking-request handling and operator workflows.

## Recommended ingestion stack

- **Unstructured** for document ingestion and parsing
- **Toaster backend** for orchestration and persistence
- **Postgres/Neon** for normalized records and operational state
- **Vector store** for semantic retrieval
- **LLM layer** for answer generation and drafting

## High-level flow

```mermaid
flowchart LR
  A[Venue source documents\nPDF / DOCX / HTML / scans / email attachments] --> B[Unstructured ingestion]
  B --> C[Normalized document records]
  C --> D[Chunking / cleanup / metadata enrichment]
  D --> E[Embedding generation]
  E --> F[(Vector store)]
  C --> G[(Postgres / Neon)]
  F --> H[Retriever]
  G --> H
  H --> I[LLM prompt context]
  I --> J[Draft answer / booking assistance]
  J --> K[Operator review]
  K --> L[Send reply or update booking request]
```

## Detailed architecture

```mermaid
flowchart LR
  subgraph Sources
    S1[Venue docs / menus / policies]
    S2[Scanned PDFs / images]
    S3[Email attachments]
    S4[Existing booking emails]
  end

  subgraph Ingestion
    I1[Unstructured API or SDK]
    I2[OCR + parsing]
    I3[Section / table extraction]
    I4[Metadata normalization]
    I5[Chunking]
    I6[Embedding generation]
  end

  subgraph Storage
    D1[(Postgres / Neon\nsource records + system of record)]
    D2[(Object storage / raw files)]
    D3[(Vector store)]
  end

  subgraph AppRuntime
    A1[Toaster backend]
    A2[Background jobs / queue]
    A3[Retriever]
    A4[Prompt assembly]
    A5[LLM]
  end

  subgraph HumanLoop
    H1[Operator inbox]
    H2[Approval / edits]
    H3[Send reply]
  end

  S1 --> I1
  S2 --> I1
  S3 --> I1
  S4 --> A1
  I1 --> I2 --> I3 --> I4
  I4 --> D1
  I4 --> D2
  I4 --> I5 --> I6 --> D3

  D1 --> A3
  D3 --> A3
  A1 --> A2 --> A3 --> A4 --> A5
  A5 --> H1
  H1 --> H2 --> H3
  H3 --> D1
```

## Toaster-specific shape

```mermaid
flowchart TB
  subgraph Ingestion
    A1[Venue docs, policies, menus, FAQs] --> A2[Unstructured]
    A2 --> A3[Structured sections + metadata]
    A3 --> A4[Chunk + embed]
  end

  subgraph Operations
    B1[Gmail / inbox message] --> B2[BookingRequest extraction]
    B2 --> B3[System of record in Postgres]
    B3 --> B4[Operator inbox + review]
  end

  subgraph Retrieval
    C1[Operator question or draft request] --> C2[Retriever]
    A4 --> C2
    B3 --> C2
    C2 --> C3[Context bundle]
    C3 --> C4[LLM draft / classification]
  end

  C4 --> B4
```

## Why Unstructured fits here

- The client is willing to pay for it, so this is not a cost-constrained decision.
- It reduces time spent building a custom document parsing pipeline.
- It is a better default when source files are inconsistent or ugly.
- It lets Toaster keep the rest of the RAG stack under our control.

## What should stay in Toaster

Keep these parts inside the app instead of outsourcing them:

- chunking policy
- embedding model choice
- retrieval ranking
- prompt assembly
- booking-request state transitions
- operator approval flow

## Design rule

Unstructured should be the **ingestion front end**, not the whole RAG system.

That keeps the architecture simple:

- vendor for document parsing
- app-owned storage and retrieval logic
- app-owned workflow state

## Notes

This diagram is intentionally conceptual. It is meant to guide implementation and issue breakdowns, not to freeze exact table names or service boundaries.
