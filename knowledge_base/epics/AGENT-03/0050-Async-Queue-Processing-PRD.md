## 0050-Async-Queue-Processing-PRD.md

#### Overview
This PRD adds async queue processing to SapAgent for batching tasks (e.g., overnight PRDs), with TTLs, encryption, and UI monitoring. Ties to vision: Enables hands-off workflows for Plaid backlog, boosting productivity in nextgen-plaid.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. Log all queue jobs, TTLs, encryptions, batch sizes, and errors in `agent_logs/sap.log` using the canonical schema extended with `sub_agent`, `queue_job_id`, `iteration`, and `pruned_tokens` where relevant. Include `timestamp`, `task_id`, `branch?`, `uuid`, `correlation_id`, `model_used`, `elapsed_ms`, `score?`, outcome. Sampling: if >100 entries/run, log every 5th after first 20. Hash PII in UI-facing logs. Rotate daily; propagate correlation_id across queue hops.

#### Requirements
- **Queue Method**: Add #queue_task to SapAgent (app/services/sap_agent.rb); input batch (e.g., 5 PRDs); use Solid Queue for async/serial (24h TTL) with queue name `sap_general`; batch guardrail max 10 (reject larger with log). Preflight checks Solid Queue presence and SapAgent::Config caps (tokens 500, iterations 7) for downstream calls.
- **Encryption**: Encrypt payloads via attr_encrypted using key from Rails.credentials (rotate quarterly) with versioned headers (v1/v2) for rotation support; include correlation_id/idempotency key in payload; anonymize payload data where possible.
- **Monitoring**: Hook to AGENT-03 UI for status (pending/completed/dead-letter) with status updates carrying correlation_id and redacted payload summary.
- **Error Handling & Safety**: Enforce TTL (24h) with rake `sap:clean_expired`; on TTL expire or failure, log and notify UI; move failed/expired to dead-letter partition `sap_dead`; per-job max runtime enforced via TimeoutWrapper; fallback to in-memory retry once if queue unavailable.

**Non-Functional Requirements:**
- Performance: Queue enqueue <100ms; process <5min/batch; retries fixed with 150ms/300ms backoff via TimeoutWrapper.
- Security: RLS for queue access; encrypt payloads end-to-end; keys rotated quarterly with version header; correlation_id for auditing.
- Compatibility: Rails 7+; Solid Queue assumed from AGENT-02C (verify/add initializer if absent).
- Privacy: Anonymize payloads; hash PII in logs; local-only processing.

#### Architectural Context
Extend SapAgent; use Solid Queue for jobs. No migrations (use existing Postgres); integrate with UI from AGENT-03-0040. Challenge: Batch size (focus on 5-10); test with mocks for determinism.

#### Acceptance Criteria
- #queue_task enqueues mock batch via Solid Queue (`sap_general`) with batch guardrails (reject >10) and correlation_id/idempotency key present.
- Applies 24h TTL with rake cleanup; expired jobs logged and moved to `sap_dead` partition.
- Encrypts payloads with versioned headers (v1/v2) using credentials key; anonymized summaries only in UI.
- UI monitors status (pending/completed/dead-letter) with redacted payload summary; SapAgent::Config caps respected downstream.
- Handles failure: Logs with extended schema + queue_job_id; notifies UI; fallback in-memory retry once if queue unavailable.

- Unit (RSpec): For #queue_task—stub Solid Queue (enqueue mock, assert TTL set and queue name); assert batch guardrail rejects >10; test encryption with versioned headers (attr_encrypted mock, credentials key); cover expire (TTL mock, assert log + dead-letter move); verify payload carries correlation_id/idempotency key and logging schema includes queue_job_id.
- Integration (Capybara): Feature spec with javascript: true; 
  - Step 1: User visits '/admin/sap-collaborate', clicks 'Queue Batch', and verifies the page shows 'Batch enqueued via Solid Queue', matching AC for enqueue.
  - Step 2: User waits for mock process, verifies the page shows 'Job expired after 24h TTL (moved to sap_dead)', matching AC for TTL/dead-letter.
  - Step 3: User checks payload, verifies the page shows 'Payload encrypted successfully (v2 key header)', matching AC for encryption.
  - Step 4: User monitors, verifies the page updates with 'Status: Completed for 3 jobs (redacted payload)', matching AC for UI monitoring.
  - Step 5: User mocks failure, verifies the page shows 'Failure logged with queue_job_id and notified; fallback in-memory retry attempted', matching AC for failure handling.
- Edge: Empty batch (no enqueue); TTL immediate expire (log + dead-letter); decryption failure (error path); soak: 10 parallel batches stay within caps and guardrails.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0050-async-queue-processing`). Ask questions and build a plan before coding (e.g., "Queue TTL logic? Encryption keys? UI status hook? Failure notification?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.