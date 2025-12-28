## 0010-Adaptive-Iteration-Engine-PRD.md

#### Overview
This PRD extends AGENT-02C's iterative prompt logic with adaptive loops in SapAgent, adding scoring-based retries and escalation for improved task refinement (e.g., PRD generation). Ties to vision: Enhances autonomous code/PRD workflows with quality controls, supporting reliable Plaid feature development in nextgen-plaid.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All adaptive iterations, scores, retries, escalations, and errors must be logged in `agent_logs/sap.log` using the canonical JSON schema from AGENT-02C, extended with `sub_agent`, `queue_job_id`, `iteration`, and `pruned_tokens` when applicable. Include `timestamp`, `task_id`, `branch?`, `uuid`, `correlation_id`, `model_used`, `elapsed_ms`, `score`, and outcome. Sampling: if >100 entries/run, log every 5th after the first 20. Redact PII in UI-facing logs by hashing user_ids/emails (SHA-256). Rotate logs daily via existing rake.

#### Requirements
**Functional Requirements:**
- **Adaptive Method**: Add #adaptive_iterate to SapAgent (app/services/sap_agent.rb); extend #iterate_prompt from AGENT-02C-0020; input task; run phased loops with shared scoring prompt/template across sub-flows (relevance, accuracy, completeness → float score 0–100) and normalized scoring when models differ (average/scale via code_execution). Use SapAgent::Config constants for thresholds/caps.
- **Caps & Budget**: Hard max 7 iterations and 500-token budget per task (cumulative, tracked via code_execution). Caps are shared across AGENT-03 methods via SapAgent::Config to avoid drift.
- **Escalation**: Start with Ollama unless ENV['ESCALATE_LLM'] is set (override starting model). Escalate only on triggers: score <70 or tokens >500. Escalation guardrails: max 1 escalation per task, track attempts in state. Fallback order on failure: Grok 4.1 → Claude Sonnet 4.5 → Ollama retry (max 2) then abort with logged warning.
- **Retries & Timeouts**: Fixed retries (max 2) with deterministic backoff (150ms then 300ms) via SapAgent::TimeoutWrapper; measure end-to-end (<300ms per round including logging/token counting).
- **Error Handling**: On budget exceed, low score failure, or escalation failure, log (with iteration + correlation_id), abort with partial output, and surface reason. Sanitise outputs; encrypt temp states if persisted.

**Non-Functional Requirements:**
- Performance: Adaptive round <300ms; total <2s for max iterations; retries are fixed (no exponential backoff). TimeoutWrapper centralises per-step limits.
- Security: Sanitize scores/outputs; encrypt temp states if persisted; hash PII in logs.
- Compatibility: Rails 7+; integrate with existing router—no new gems.
- Privacy: Local Ollama priority; no external data in evals; correlation_id propagated across queue hops if queued later.

#### Architectural Context
Build on AGENT-02C-0020 in app/services/sap_agent.rb; use router for LLM calls/escalation. No models/migrations; states as JSON. Challenge: Prevent over-escalation (focus on scoring accuracy); test with VCR mocks for determinism, Ollama stubs.

#### Acceptance Criteria
- #adaptive_iterate runs mock task with shared scoring prompt and normalization; <80% triggers retry (max 2 with 150/300ms backoff).
- Escalates on score <70 or tokens >500; honors ENV['ESCALATE_LLM'] override for start; fallback order Grok → Claude → Ollama retry; cap escalations to 1 per task and log attempts.
- Enforces SapAgent::Config caps (max 7 iterations, 500 tokens cumulative) with logged iteration numbers and correlation_id.
- Handles failure: Logs error with schema (incl. iteration, sub_agent nil, queue_job_id nil), aborts with partial output and warning surfaced.
- Integrates with AGENT-02C phases for decomposition and shares config constants across AGENT-03 methods.

- Unit (RSpec): For #adaptive_iterate—stub Ollama (mock scores: 75% → retry 2x, then 85% → stop); assert retries count ==2 with 150/300ms waits; test escalation (score <70 or tokens >500 → Grok; env override start model; fallback to Claude then Ollama retry); cover caps (force 8 iterations, assert abort at 7 and 1 escalation max); budget exceed (mock token count >500 cumulative, assert log/partial with correlation_id); verify normalization applied when model changes and escalation attempt recorded in state.
- Integration (Capybara): Feature spec with javascript: true; 
  - Step 1: User visits '/admin/sap-collaborate', selects task 'Generate PRD', clicks 'Start Adaptive Iteration', and verifies the page shows 'Iteration 1 complete - Score: 75% - Retrying (1/2)', matching AC for <80% retry.
  - Step 2: User mocks score <70% or tokens >500, verifies the page shows 'Escalated to Grok 4.1 for iteration 3 (1/1 escalation used)', matching AC for escalation; if Grok fails, page shows 'Falling back to Claude Sonnet 4.5 then Ollama retry'.
  - Step 3: User forces max iterations, verifies the page shows 'Aborted at max 7 iterations (SapAgent::Config)', matching AC for iteration cap.
  - Step 4: User mocks token >500, verifies the page shows 'Budget exceeded: Logged error with correlation_id, partial output returned', matching AC for budget enforcement.
  - Step 5: User checks failure mock, verifies the page shows 'Error handled: Aborted with partial output logged (schema fields present)', matching AC for error handling.
- Edge: No retries needed (>80% immediate); repeated low scores (escalate once then abort); empty task (error log); soak: 10 parallel adaptive loops mocked respect caps without extra escalations.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0010-adaptive-iteration-engine`). Ask questions and build a plan before coding (e.g., "Scoring eval prompt? Escalation env? Budget tracking? State JSON format?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.