### 0010-SAP-Code-Review-Method-PRD.md

#### Overview
This PRD implements a code review method in SapAgent to fetch and analyze targeted repo context using browse_page/code_execution tools, integrating RuboCop for style checks, and outputting a structured review format. Ties to vision: Enables post-implementation analysis for Plaid features (e.g., sync jobs), ensuring high-quality code for privacy and reliability in family wealth stewardship.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All review operations, tool calls, analysis, and errors must be logged in `agent_logs/sap.log` with structured entries (e.g., timestamp, reviewed files, RuboCop issues, outcome). Rotate logs daily via existing rake.

#### Requirements
**Functional Requirements:**
- **Review Method**: Add #code_review to SapAgent (app/services/sap_agent.rb); take branch/commit as input, fetch 3-5 key files/diffs via browse_page (e.g., raw URLs like https://raw.githubusercontent.com/ericsmith66/nextgen-plaid/main/app/models/plaid_item.rb), parse/analyze with code_execution (e.g., diff parsing), run RuboCop on extracted code.
- **Output Structure**: Generate structured JSON/MD: { "strengths": [array of positives, e.g., "Clean MVC"], "weaknesses": [e.g., "Missing tests"], "issues": [RuboCop offenses with line numbers], "recommendations": [actionable fixes, e.g., "Add VCR mock"] }; default Ollama for analysis to control cost/limits.
- **Targeting Logic**: Limit to changed files (parse git diff via code_execution); prioritize models/services/tests; chunk large files (>2K lines) for Ollama.
- **Error Handling**: On tool failure (e.g., 404 URL), log error and fallback to local git if available; skip RuboCop if not configured.

**Non-Functional Requirements:**
- Performance: Review <300ms for 5 files; Ollama calls async if needed.
- Security: Read-only tool calls; sanitize outputs for injection.
- Compatibility: Rails 7+; use existing tools—no new gems beyond RuboCop if not installed.
- Privacy: No raw data in reviews; align with local Ollama.

#### Architectural Context
Integrate into SapAgent from Epic 1/2; call in decompose/router for post-PR reviews. Use Rails service method; no models/migrations. Leverage Epic 1 tools (browse_page for raw files, code_execution for parsing/RuboCop run via Python if Ruby not sufficient). Default Ollama (70B) via AiFinancialAdvisor for static analysis. Test with mock tool responses (VCR for browse). Challenge: Handle repo access limits (fallback to pasted code if tool fails); focus on 3-5 files to avoid overload.

#### Acceptance Criteria
- #code_review fetches mock branch files via browse_page and analyzes with code_execution/RuboCop.
- Output JSON has all sections populated (e.g., issues lists 2 offenses).
- Targets only changed files (e.g., ignores unrelated like config/).
- Chunking works for large file (e.g., split >2K lines, separate Ollama calls).
- Tool failure logs error and skips (no crash).
- Review uses Ollama default; toggle to Grok if dynamic needed.

#### Test Cases
- Unit (RSpec): For #code_review—stub browse_page/code_execution, assert output['strengths'].size >0, output['issues'] includes RuboCop mocks; test chunking (mock large string, assert multiple calls).
- Integration: Simulate review on sample branch, assert output matches expected format; Capybara-like: Feature spec with javascript: true to visit /admin/review_branch, fill_in 'Branch', click 'Run Review', expect page.to have_content('Strengths: Clean MVC'), expect page.to have_content('Issues: 2 offenses'), expect page.to have_no_content('Unrelated files'), cover chunking by mocking large file (expect page.to have_content('Chunked analysis complete')), tool failure (expect page.to have_content('Error logged, skipped')), Ollama toggle (set env, expect page.to have_content('Grok used for dynamic')).
- Edge: No changes (empty review); RuboCop errors (fallback to manual issues); private repo 404 (skip with log).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0010-sap-code-review-method`). Ask questions and build a plan before coding (e.g., "RuboCop config location? Tool stub in tests? Chunk size limit? Toggle for Grok?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.
