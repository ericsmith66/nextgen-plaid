### 0010-SAP-RAG-Concat-Framework-PRD.md

#### Overview
This PRD extends the existing FinancialSnapshotJob (from README features for daily syncs) to generate project-state JSON blobs for simple RAG concat, capturing history (e.g., merged PRDs 0010-0060 for Plaid holdings/transactions), vision/goals (MCP from knowledge_base/static_docs/), backlog (priorities from TODO.md like reconnect button, tests), and code state summaries (e.g., schema.rb minified). Ties to vision: Provides accurate context prefix for SAP prompt to reduce hallucinations in PRD generation, supporting reliable Plaid syncs for JPMC/Schwab/Amex/Stellar without duplication.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All JSON generation, concat operations, and errors must be logged in `agent_logs/sap.log` with structured entries (e.g., timestamp, job run, blob size, outcome). Rotate logs daily via existing rake.

#### Requirements
**Functional Requirements:**
- **JSON Blob Generation**: Extend FinancialSnapshotJob to create daily sanitized JSON (e.g., { "history": [array of merged PRDs with titles/IDs extracted from git log regex like /Merged PRD (\d+)/], "vision": [array of key excerpts from MCP/static_docs, e.g., "estate-tax sunset" paragraphs], "backlog": [array of objects from TODO.md parsed as table with Priority/ID/Title/Description/Status/Dependencies], "code_state": [object with minified db/schema.rb, rails routes output, Gemfile.lock summary] }).
- **Concat for RAG**: Add #rag_context method in SapAgent (app/services/sap_agent.rb) to load latest snapshot JSON from knowledge_base/snapshots/ and concat as string prefix to system prompt (e.g., "Project Context: #{json_string}"); auto-summarize sections if total >4K chars.
- **Summarization Strategy**: Use deterministic summarization: first N lines + tail for history; keyword extraction for vision; regex-based minification for `schema.rb` (table/column names/types only, omit indices/FKs). Escalate to LLM (Ollama) via toggle if deterministic is insufficient.
- **Trigger & Retention**: Schedule via `recurring.yml` (daily 3am). Retain last 7 daily snapshots; archive/delete older via rake (weekly) and log deletions.
- **UI Extension**: Add optional `/admin/rag_inspector` in Mission Control (Streamlit-like simplicity) to view latest snapshot/inventory/backlog JSON.
- **Error Handling**: Fallback to `inventory.json` if git is unavailable. Log "Truncated [section]" on oversized blobs.

**Non-Functional Requirements:**
- Performance: Blob generation <200ms; concat <50ms.
- Security: Sanitize JSON; verify `GITHUB_WEBHOOK_SECRET` signature for automation triggers (see 0040).
- Privacy: No sensitive data (tokens/PII); align with local-only.

#### Architectural Context
Build on Epic 1's SapAgent service by injecting RAG concat into prompt building (e.g., in ArtifactCommand#prompt or Router). Store blobs in knowledge_base/snapshots/ as dated files (e.g., 2025-12-27-project-snapshot.json) for audit. Use Rails MVC: Job for generation logic, no new models/migrations. Parse git log via system("git log --grep='Merged PRD'"); use code_execution if needed for complex parsing in tests. Defer advanced RAG—focus on simple concat prefix. Challenge: Limit summaries to essential (e.g., vision to 5 key sentences); browse_page repo if git local unavailable in tests.

#### Acceptance Criteria
- FinancialSnapshotJob generates JSON blob with all sections populated from mock repo data (e.g., history has at least 2 PRD entries).
- SapAgent #rag_context loads blob and prepends to prompt without errors (full prompt includes "Project Context: {...}").
- Daily Sidekiq schedule added; rake sap:generate_snapshot creates valid blob file.
- Oversized blob auto-summarizes (e.g., history >500 chars reduced to summaries like "PRD 0060: Holdings extension details").
- Missing file (e.g., no TODO.md) uses empty backlog array and logs warning without job failure.
- Privacy check: Generated JSON has no encrypted fields or tokens (manual inspection shows clean summaries).
- Manual trigger via rake succeeds in <200ms on standard repo.

#### Test Cases
- Unit (RSpec): For FinancialSnapshotJob#perform—stub system("git log") and File.read, assert json['history'].size == expected, json.keys.include?('vision'); test summarization (mock large string, assert json['code_state']['schema'].length < 2000).
- Integration: Enqueue job, assert File.exist?(knowledge_base/snapshots/*.json) and JSON.parse valid; test SapAgent prompt concat (mock blob, assert_match /Project Context: \{.*backlog.*\}/, router_prompt); Capybara-like: Visit dashboard (if tied), feature spec to simulate cron run and verify no UI errors, but focus on backend (e.g., expect { job.perform_now }.to change { Dir.glob('knowledge_base/snapshots/*.json').size }.by(1)); cover AC with scenarios like oversized history (expect log.include?('Truncated history')) and missing static_docs (expect json['vision'] == []).
- Edge: Invalid git output (stub empty log, expect empty history and warning log); oversized total (expect summarized sections and blob.size < 4096 chars).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0010-sap-rag-concat-framework`). Ask questions and build a plan before coding (e.g., "JSON structure details for backlog objects? Summarization algorithm (e.g., truncate or AI-summarize)? Git log regex for PRD IDs? Fallback for no recurring.yml? Token limit calculation method?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.
