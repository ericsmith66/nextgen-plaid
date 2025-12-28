## 0020-Multi-Agent-Conductor-PRD.md

#### Overview
This PRD implements a Conductor role in SapAgent to orchestrate multi-agent workflows, routing sub-agents (Outliner/Refiner/Reviewer) iteratively via Solid Queue for task decomposition. Ties to vision: Enables collaborative iteration for complex Plaid PRDs, improving dev efficiency in nextgen-plaid.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. Log all conductor routings, sub-agent calls, state serializations, and errors in `agent_logs/sap.log` using the canonical JSON schema (timestamp, task_id, branch?, uuid, correlation_id, model_used, elapsed_ms, score?) extended with `sub_agent`, `queue_job_id`, `iteration`, and `pruned_tokens` when relevant. Sampling: if >100 entries/run, log every 5th after the first 20. Redact PII in UI-related logs (hash user/emails). Rotate logs daily via existing rake; propagate correlation_id across queue hops.

#### Requirements
**Functional Requirements:**
- **Conductor Method**: Add Conductor module/class to SapAgent (app/services/sap_agent.rb); decompose task into sub-agents (Outliner: break phases, Refiner: iterate sections, Reviewer: score final) using the shared scoring template/normalization from 0010. Use SapAgent::Config constants for caps and thresholds.
- **Routing**: Serial Solid Queue (queue name `sap_conductor`) for calls (Outliner first, then Refiner x3-5, Reviewer last); serialize/restore state via JSON blobs (code_execution for parse/save) with JSON schema validation before resume. Preflight enforces max 5 jobs; include idempotency key (UUID) and correlation_id in each payload.
- **Integration**: Hook to AGENT-02C-0040 roles; honor SapAgent::Config caps (iterations 7/tokens 500) when sub-agents iterate/refine.
- **Resilience & Guardrails**: Circuit-breaker: halt queue routing after 3 consecutive failures and log; fallback to sequential in-memory with warning. Escalation guardrail: max 1 escalation per task (tracked in state) following router order Grok → Claude → Ollama retry.
- **Error Handling**: On queue failure, validation error, or TTL breach, log with queue_job_id/sub_agent; fallback to in-memory flow and preserve partial output.

**Non-Functional Requirements:**
- Performance: Routing <100ms; queue latency <1s; per-step timeouts via SapAgent::TimeoutWrapper with fixed retries/backoff (150ms/300ms) where applicable.
- Security: Encrypt JSON states (key from Rails.credentials, rotate quarterly); auth queue access; propagate correlation_id for auditing.
- Compatibility: Rails 7+; Solid Queue present/verified (initializer if missing).
- Privacy: Local processing; no external queues; hash PII in logs.

#### Architectural Context
Extend SapAgent from AGENT-02C-0040; use Solid Queue for async/serial. No models/migrations; states as temp JSON. Challenge: State consistency (focus on serialization); test with mocks for determinism, VCR for queues.

#### Acceptance Criteria
- Conductor decomposes mock task into sub-agents and routes via Solid Queue (`sap_conductor`) with idempotency key + correlation_id in payloads.
- Serial execution: Outliner → Refiner (3-5) → Reviewer, honoring shared scoring template/normalization and SapAgent::Config caps (iterations/tokens) inside sub-flows.
- Serializes/restores state JSON between jobs with schema validation; logs iteration/sub_agent/queue_job_id.
- Handles failure: Circuit-breaker trips after 3 consecutive queue failures, logs, and falls back to in-memory while preserving partial output.
- Limits to max 5 jobs per task via preflight; abort extra with logged warning.

- Unit (RSpec): For Conductor—stub sub-agents (mock Outliner output, Refiner iterations, Reviewer score); assert routing order; test serialization (JSON dump/load via code_execution, schema validation pass/fail); enforce max 5 jobs preflight; cover failure (queue mock fail → circuit-breaker after 3, fallback to in-memory); verify payload carries idempotency key + correlation_id and logging schema includes queue_job_id/sub_agent.
- Integration (Capybara): Feature spec with javascript: true; 
  - Step 1: User visits '/admin/sap-collaborate', selects task 'Decompose PRD', clicks 'Orchestrate', and verifies the page shows 'Routed to Outliner - Phase broken into 4', matching AC for decomposition and routing.
  - Step 2: User waits for queue process, verifies the page shows 'Refiner completed 3 iterations', matching AC for serial Refiner execution.
  - Step 3: User completes flow, verifies the page shows 'Reviewer scored final output', matching AC for Reviewer last and normalized scoring.
  - Step 4: User mocks state, verifies the page shows 'State restored from JSON between jobs (schema validated)', matching AC for serialize/restore.
  - Step 5: User mocks queue failure streak, verifies the page shows 'Circuit-breaker tripped after 3 failures - Falling back to in-memory', matching AC for failure handling.
- Edge: Max 5 jobs (abort extra); empty decomposition (log error); corrupted JSON (fallback log); soak: 5 conductor chains mocked stay within caps and do not exceed 1 escalation/task.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0020-multi-agent-conductor`). Ask questions and build a plan before coding (e.g., "Sub-agent rules? Queue serialization? Failure fallback? Max job limit?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.