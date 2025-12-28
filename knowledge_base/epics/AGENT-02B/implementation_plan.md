# Implementation Plan: AGENT-02B (RAG & Backlog Management)

## Overview
This plan outlines the sequential implementation of Epic 2, extending the SAP agent with context-aware RAG and automated backlog management.

## Phase 1: RAG Concat Framework (0010)
- [ ] **Data Source**: Extend `FinancialSnapshotJob` to generate `knowledge_base/snapshots/[DATE]-project-snapshot.json`.
    - Extract history from git log (Regex: `Merged PRD (\d+)`).
    - Extract vision from `knowledge_base/static_docs/MCP.md`.
    - Extract backlog from `backlog.json`.
    - Extract code state (minified `schema.rb`).
- [ ] **Summarization**: Implement deterministic truncation for `schema.rb` (tables/columns only) and history.
- [ ] **Integration**: Add `#rag_context` to `SapAgent::ArtifactCommand` to inject the snapshot into prompts.
- [ ] **Automation**: Update `recurring.yml` for daily runs and implement snapshot retention (7 days).
- [ ] **Admin UI**: Add `/admin/rag_inspector` for manual verification of snapshot data.

## Phase 2: Inventory Rake Task (0020)
- [ ] **Rake Task**: Create `lib/tasks/sap_inventory.rake`.
- [ ] **Metadata**: Implement frontmatter parsing for `.md` files in `knowledge_base/`.
- [ ] **Storage**: Generate `knowledge_base/inventory.json`.

## Phase 3: Backlog Management Methods (0030)
- [ ] **Service Methods**: Add `#update_backlog`, `#prune_backlog`, `#sync_backlog` to `SapAgent`.
- [ ] **Logic**: Implement auto-status detection via git and YAGNI pruning (archive to `backlog_archive.json`).
- [ ] **Bidirectional Sync**: Ensure `TODO.md` stays in sync with `backlog.json`.

## Phase 4: Webhook Extension (0040)
- [ ] **Controller**: Extend `PlaidWebhookController` to handle GitHub `push` events.
- [ ] **Security**: Implement HMAC signature validation using `GITHUB_WEBHOOK_SECRET`.
- [ ] **Orchestration**: Trigger `sap_inventory` and `update_backlog` post-merge.

## Verification
- [ ] Unit tests for `FinancialSnapshotJob`.
- [ ] Integration tests for `SapAgent` RAG injection.
- [ ] RSpec for `PlaidWebhookController` GitHub event handling.
- [ ] Manual verification via `/admin/rag_inspector`.
