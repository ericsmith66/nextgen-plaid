### 0030-SAP-Backlog-Management-Methods-PRD.md

#### Overview
This PRD adds methods to SapAgent for generating/updating/pruning backlog tables from TODO.md and inventory.json, with Effort/Deadline columns and auto-status detection via git log. Ties to vision: Enables dynamic backlog in SAP PRDs, preventing duplication and prioritizing Plaid features like transaction syncs.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All backlog operations, prunes, and errors must be logged in `agent_logs/sap.log` with structured entries (e.g., timestamp, updated items, prune count, outcome). Rotate logs daily via existing rake.

#### Requirements
**Functional Requirements:**
- **Backlog SSOT & Sync**: Add #generate_backlog, #update_backlog, #prune_backlog, #archive_backlog, and #sync_backlog to SapAgent. `backlog.json` is the SSOT. `TODO.md` is a human-readable view generated from JSON. Implement bidirectional sync (prioritizing JSON for AI).
- **Prune & Archive**: Move pruned items (Low/stale >30 days) to `knowledge_base/backlog_archive.json` instead of deletion. Add restore method. Log rationale.
- **Auto-Status Detection**: Use git log regex on PRD IDs (e.g., "Merged PRD 0010") to detect completion.
- **Effort & Deadline**: Effort 1-5 based on complexity keywords. Deadline default +30 days or parsed from query.
- **Integration**: Injects updated backlog table into PRD/Epic generation prompts. Save state in `backlog.json`.
- **Error Handling**: No prune on High-priority items. Fallback to empty table on parse errors.

**Non-Functional Requirements:**
- Performance: Operations <100ms for 20 items.
- Security: Read-only for git; atomic writes for `backlog.json`.
- Compatibility: Rails 7+; no new gems.
- Privacy: No sensitive data in backlog.

#### Architectural Context
Build on SapAgent from Epic 1; integrate with RAG concat (include backlog table in JSON blob). Use Rails: Service methods, no new files beyond backlog.json. Parse git via system("git log"); use code_execution in tests for regex. Challenge: Accurate Effort estimation (keyword-based, e.g., "complex" =5); limit table to 50 items.

#### Acceptance Criteria
- #generate_backlog parses mock TODO.md to table with all columns.
- #update_backlog detects status from git log (e.g., "Todo" to "Completed").
- #prune_backlog removes 2 Low/stale items, logs rationale.
- PRD prompt output includes updated table.
- backlog.json saved and loaded correctly.
- No prune on High items; log warning on parse error.

#### Test Cases
- Unit (RSpec): For #generate_backlog—stub File.read, assert table.size == 5, table[0]['Effort'] == 3; for #prune_backlog, mock stale, assert pruned.count == 2.
- Integration: Call methods in SapAgent flow, assert backlog.json updated; Capybara-like: Feature spec to simulate PRD generation (expect prompt.include? backlog table), cover AC with scenarios like status update (mock git log, expect 'Status' = 'Completed'), prune (expect log.include?('YAGNI prune')), error (mock bad TODO.md, expect empty table); test no High prune.
- Edge: Empty TODO.md (empty table); no git matches (keep Todo).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0030-sap-backlog-management-methods`). Ask questions and build a plan before coding (e.g., "Effort calculation keywords? Prune criteria details? Git log regex? Integrate with RAG concat?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.
