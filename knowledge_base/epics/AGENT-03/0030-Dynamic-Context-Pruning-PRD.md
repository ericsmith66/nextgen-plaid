## 0030-Dynamic-Context-Pruning-PRD.md

#### Overview
This PRD adds dynamic context pruning to SapAgent for mid-iteration summarization, using heuristics to keep token budgets low. Ties to vision: Optimizes RAG for efficient AI responses in Plaid data analysis, reducing costs in nextgen-plaid.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. Log all pruning operations, heuristics, token counts, retained/dropped sections, and errors in `agent_logs/sap.log` using the canonical JSON schema extended with `sub_agent`, `queue_job_id`, `iteration`, and `pruned_tokens`. Include `timestamp`, `task_id`, `branch?`, `uuid`, `correlation_id`, `model_used`, `elapsed_ms`, `score?`, and outcome. Sampling: if >100 entries/run, log every 5th after the first 20. Hash PII for UI-related logs. Rotate logs daily via existing rake.

#### Requirements
- **Prune Method**: Add #prune_context to SapAgent (app/services/sap_agent.rb); input context (e.g., backlog.json + prior outputs); heuristic: target <4k tokens/call and >=2k min-keep floor using code_execution token count; relevance via Ollama eval (weight 70%) + age prune >30 days (weight 30%, timestamp parse via code_execution); log retained vs dropped with reasons. Use SapAgent::Config constants for caps.
- **Integration**: Hook to AGENT-02B RAG layering; PGVector completely deferred until post-validation—expose feature flag stub ENV['USE_PGVECTOR'] but no implementation.
- **Output**: Return minified context (e.g., tables/columns only for schema) while honoring min-keep floor unless user approval provided via UI prompt.
- **Error Handling**: On prune failure or validation issue, log warning with schema, return full context with warning banner; propagate correlation_id.

**Non-Functional Requirements:**
- Performance: Prune <200ms end-to-end (includes token counting/logging); deterministic backoff (150ms/300ms) via TimeoutWrapper for retries if needed.
- Security: Sanitize pruned output; hash PII in logs; encrypt temp states if persisted.
- Compatibility: Rails 7+; PGVector flag only (no gem until enabled later).
- Privacy: Local eval; no data loss; enforce SapAgent::Config caps on tokens shared across AGENT-03.

#### Architectural Context
Extend SapAgent from AGENT-02B; use code_execution for counts/parsing. No models/migrations initially; PGVector optional in Postgres. Challenge: Balance relevance/loss (focus on heuristics); test with mocks for determinism.

#### Acceptance Criteria
- #prune_context reduces mock context to <4k tokens while keeping >=2k tokens floor; logs pruned_tokens and retained/dropped reasons.
- Applies weighted heuristic: relevance eval (Ollama score >0.5 retain, 70% weight) and age prune (>30 days remove, 30% weight) using code_execution; honors SapAgent::Config token caps.
- Returns minified output (e.g., schema tables only) unless floor prevents further pruning; surfaces warning if user approval needed to go below 2k.
- Handles failure: Logs warning with schema fields/correlation_id, returns full context with banner.
- PGVector remains deferred; ENV['USE_PGVECTOR'] stub exists but no switch until validated.

- Unit (RSpec): For #prune_context—stub code_execution (token count mock >4k → prune to 3k but not below 2k floor); Ollama eval (score mock, retain high per 70% weight); age parse (timestamp >30 days, remove per 30% weight); assert minified (e.g., full schema → tables/columns) and logging includes pruned_tokens/retained reasons; failure path returns full context with warning.
- Integration (Capybara): Feature spec with javascript: true; 
  - Step 1: User visits '/admin/sap-collaborate', uploads mock context >4k tokens, clicks 'Prune', and verifies the page shows 'Pruned to 3500 tokens', matching AC for token reduction.
  - Step 2: User mocks low relevance, verifies the page shows 'Retained high-score sections only (score >0.5)', matching AC for relevance eval.
  - Step 3: User mocks old timestamps, verifies the page shows 'Pruned items >30 days old', matching AC for age prune.
  - Step 4: User checks output, verifies the page shows 'Minified schema: tables/columns only (>=2k tokens retained)', matching AC for minified output with floor respected.
  - Step 5: User mocks failure, verifies the page shows 'Warning logged with correlation_id: Returned full context', matching AC for failure handling.
- Edge: Empty context (no prune); max size (prune aggressively but respect 2k floor); PGVector flag present but no switch; soak: 10 parallel pruning calls stay within caps and timeouts.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0030-dynamic-context-pruning`). Ask questions and build a plan before coding (e.g., "Heuristic details? Token count logic? Age parse? PGVector env?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.