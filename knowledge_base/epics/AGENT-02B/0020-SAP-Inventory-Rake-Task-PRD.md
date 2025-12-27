### 0020-SAP-Inventory-Rake-Task-PRD.md

#### Overview
This PRD creates a rake task to scan knowledge_base/ for epics/PRDs and generate/update inventory.json with metadata (titles, statuses, dependencies), enabling RAG freshness for history/goals. Ties to vision: Supports accurate context in SAP for backlog/PRD avoidance, aiding Plaid feature planning like liability syncs without redundancy.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All scan operations, JSON updates, and errors must be logged in `agent_logs/sap.log` with structured entries (e.g., timestamp, scanned files, update count, outcome). Rotate logs daily via existing rake.

#### Requirements
**Functional Requirements:**
- **Rake Task Creation**: Add lib/tasks/sap_inventory.rake with #perform to scan knowledge_base/epics/ and knowledge_base/prds/ for .md files.
- **Metadata Extraction**: Use a lightweight frontmatter parser (regex for YAML block `---` at top of MD). Extract title, priority, status, and dependencies. Fallback to regex (e.g., `# (.*)` for title) if no frontmatter found.
- **Inventory Update**: Generate/update knowledge_base/inventory.json as array of objects (e.g., { "id": "0010", "title": "RAG Framework", "status": "Todo", "priority": "High", "dependencies": ["Epic 1"] }); compare mod dates to avoid unnecessary rewrites.
- **Trigger Integration**: Run on demand (rake sap:inventory); auto-trigger post-merge via webhook extension (0040); tie to `recurring.yml`.
- **Error Handling**: Skip invalid MD files and log warning. Handle large dirs (max 100 files). Fallback for missing git.

**Non-Functional Requirements:**
- Performance: Scan <100ms for 50 files; JSON write <50ms.
- Security: Read-only scan; slugify keys for safety.
- Compatibility: Rails 7+; no new gems.
- Privacy: Metadata only; no sensitive content extraction.

#### Architectural Context
Integrate with Epic 1's SapAgent by loading inventory.json in #rag_context for history section. Use Rails conventions: Rake for task, no controllers/jobs here. Parse MD with simple regex (e.g., /# (.*)/ for title); use code_execution in tests for complex parsing. Defer full semantic search—focus on file-based inventory. Challenge: Handle large dirs (limit to 100 files max); browse_page repo if needed for verification in tests.

#### Acceptance Criteria
- Rake sap:inventory scans mock knowledge_base/ and generates inventory.json with correct metadata for 3 files.
- JSON updates only on changes (e.g., new .md added triggers rewrite; unchanged skips).
- Daily recurring.yml entry added for auto-run.
- Invalid file skipped with log warning; empty dir creates empty JSON array.
- Metadata accurate (e.g., title matches header, status parsed from "Status: Todo" in AC).
- Manual run succeeds in <100ms.

#### Test Cases
- Unit (RSpec): For rake task—stub Dir.glob/File.read, assert json['length'] == 3, json[0]['title'] == expected; test update logic (mock same mod date, assert no write).
- Integration: Invoke rake, assert File.exist?(inventory.json) and JSON.parse valid; Capybara-like: Feature spec to simulate post-merge trigger (mock webhook, expect job.enqueued?), verify no UI impact, cover AC with scenarios like invalid MD (expect log.include?('Skipped invalid')) and empty dir (expect json == []); test daily cron by checking recurring.yml parse.
- Edge: Large dir (mock 200 files, expect limited to 100 with log); parse errors (mock bad header, expect skipped).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0020-sap-inventory-rake-task`). Ask questions and build a plan before coding (e.g., "Regex for status/dependencies? Limit on file count? Tie to recurring.yml format? Error on non-MD files?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.
