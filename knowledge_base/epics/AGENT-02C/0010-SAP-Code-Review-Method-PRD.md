## 0010-SAP-Code-Review-Method-PRD.md

#### Overview
This PRD implements a code review method in SapAgent to fetch and analyze targeted repo context (3-5 files) using browse_page/code_execution tools, integrating RuboCop for style checks, and outputting a structured JSON/MD review format. Ties to vision: Enables post-implementation analysis for Plaid features (e.g., sync jobs), ensuring high-quality code for privacy and reliability in family wealth stewardship.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All review operations, tool calls, analysis, and errors must follow the canonical JSON schema in `agent_logs/sap.log`: { "timestamp": "ISO8601", "task_id": "string", "branch": "string (optional)", "uuid": "string", "correlation_id": "uuid", "model_used": "string", "elapsed_ms": integer, "score": float (optional) }. Logs remain file-only (no dashboard emission yet); rotate daily via existing rake.

#### Requirements
**Functional Requirements:**
- **Review Method**: Add #code_review to SapAgent (app/services/sap_agent.rb); input branch/commit; select 3-5 files via git diff (code_execution parse) prioritizing added/modified files in models/services/tests, then highest churn; explicitly exclude deleted/binary files (.bin/.jpg etc.); fetch raw content via browse_page (e.g., raw URLs like https://raw.githubusercontent.com/ericsmith66/nextgen-plaid/main/app/models/plaid_item.rb). Fallback when git unavailable: accept pasted/backlog-linked files and log warning.
- **Analysis**: Run RuboCop on extracted code using config/rubocop.yml (pin RuboCop >=1.60 in Gemfile); write snippets to tmp via code_execution and run with Metrics cops disabled, focusing on Lint/Security/Style; cap returned offenses to top 20 by severity and enforce TimeoutWrapper 30s.
- **Redaction**: Apply regex /\b(API_KEY|SECRET|TOKEN|PASSWORD|ENV[\w_]+)\b/i; hash matches (SHA-256) to preserve structure; use allowlist/denylist in config/redaction.yml to avoid over-redaction; do not redact emails/domains unless matched.
- **Output Structure**: JSON: { "strengths": [array of strings, e.g., "Clean MVC"], "weaknesses": [e.g., "Missing tests"], "issues": [array of { "offense": string, "line": int }], "recommendations": [actionable strings, e.g., "Add VCR mock"] }; store in sap.log.
- **Error Handling**: On tool failure (e.g., 404), log and fallback to local git if available; timeout RuboCop at 30s.

**Non-Functional Requirements:**
- Performance: Review <300ms for 5 files; tool calls async if needed; hard budget 1000 tokens/run (log+abort on exceed); cap RuboCop at 30s.
- Security: Read-only; sanitize outputs for injection; privacy: no PII in reviews; DaisyUI toast/stdout alert for web-triggered errors.
- Compatibility: Rails 7+; use existing gems (add RuboCop if missing—no new deps beyond it); RuboCop pinned >=1.60.
- Privacy & Models: Default Ollama 70B; escalate to Grok 4.1 on score <70 or token budget >500; Claude Sonnet 4.5 on env toggle or Grok unavailable; hard cost/iteration ceiling 1000 tokens/run.

#### Architectural Context
Integrate into SapAgent from AGENT-02A/B; call in router for post-PR reviews. Use Rails service method; no models/migrations. Leverage tools (browse_page for raw files, code_execution for diff parsing/RuboCop run). Default Ollama (70B) via AiFinancialAdvisor. Challenge: Handle rate limits (fallback to pasted code); focus on 3-5 files to avoid overload. Test with VCR/WebMock for determinism.

#### Acceptance Criteria
- #code_review selects 3-5 added/modified files from mock branch via code_execution/git diff, prioritizing models/services/tests then churn, excluding deleted/binary.
- Fetches content via browse_page and analyzes with RuboCop (Lint/Security/Style only), redacting secrets via regex+hash and honoring config/redaction.yml allow/deny.
- Output JSON has all keys populated and logs follow canonical schema with correlation_id/uuid/model_used/elapsed_ms; top 20 offenses only.
- Handles tool failure or git unavailable: Logs warning, falls back to provided/pasted files without crash.
- Timeout enforces 30s limit on RuboCop via TimeoutWrapper; review aborts if token budget exceeds 1000 with logged error.
- Uses Ollama default; escalates to Grok 4.1 on score <70 or tokens >500; Claude Sonnet 4.5 if env toggle or Grok unavailable.

#### Test Cases
- Unit (RSpec): For #code_review—stub code_execution (git diff mock returning 4 files ordered by models/services/tests then churn), browse_page (raw content), RuboCop (offenses array limited to 20, Metrics disabled); assert output['strengths'].size >0, output['issues'][0]['line'] == 10; test redaction hashing with allowlist/denylist (config/redaction.yml); cover timeout (Timeout.raise after 30s mock) and token budget exceed (log/abort).
- Integration (Capybara): Feature spec with javascript: true; 
  - Step 1: User visits '/admin/sap-collaborate', fills in branch name with 'feature/test-branch', clicks 'Run Review', and verifies the page displays 'Strengths: Clean MVC adherence' and 'Issues: 2 offenses on lines 5 and 10', matching AC for file selection and populated output.
  - Step 2: User triggers review with mocked sensitive content, verifies the page has no 'Sensitive API_KEY exposed', matching AC for redaction.
  - Step 3: User runs review with stubbed 404 tool failure, verifies the page shows 'Error logged: File fetch failed, skipped analysis', matching AC for error handling.
  - Step 4: User sets ENV['ESCALATE_LLM'] = 'grok' and runs review, verifies the page shows 'Escalated to Grok 4.1 for complex analysis', matching AC for escalation; if Grok unavailable and env toggle set to claude, verify Claude Sonnet 4.5 used.
  - Step 5: User runs review with mocked timeout, verifies the page shows 'Timeout enforced at 30s for RuboCop', matching AC for timeout; token budget exceed shows 'Budget exceeded: aborted at 1000 tokens logged'.
- Edge: Empty diff (minimal output with log 'No changes detected'); large file (chunk via code_execution, assert multiple analyses in output); private repo failure (fallback log 'Access denied, using local git mock'); binary/deleted files ignored.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0010-sap-code-review-method`). Ask questions and build a plan before coding (e.g., "RuboCop config location? Tool stubs in tests? Redaction regex? Escalation env var?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.