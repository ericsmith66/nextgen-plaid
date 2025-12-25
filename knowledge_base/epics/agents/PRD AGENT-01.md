### Atomic PRD 1: Set Up Solid Queue for Agent Communication

**Overview**  
This feature establishes asynchronous communication queues using Solid Queue (Rails 8 default) to enable independent interactions among agent personas in the three-persona POC for multi-agent architecture in nextgen-plaid. Specifically, it supports the SAP (Senior Architect and Product Manager) in delegating atomic PRDs to the CWA (Code Writer Agent) for implementation planning, and facilitates CWA queuing of generated code/commands to the CSO (Chief Security Officer) for dynamic evaluation, ensuring separation of duties with minimal human intervention. This is the foundational step toward C-suite-like autonomy, aligning with the virtual family office vision for scalable AI-driven wealth stewardship training.

**Epic Summary**: This epic implements a POC for three-persona (SAP, CWA, CSO) interactions via asynchronous queues, allowing agents to run independently with limited human input (e.g., via SAP queries or CSO escalations). It proves the multi-agent foundation for expanding to full personas (e.g., CFO, Tax Attorney) in the AI tutor/internship system, using local Ollama for privacy-focused decisions. Other PRDs in this epic: (2) SAP service for query/PRD gen and delegation; (3) CWA service for PRD review/code gen and CSO queuing; (4) CSO service for command eval and feedback; (5) AgentLog model and rake task for auditing/initiation.

**End of Epic Capabilities**: Full asynchronous agent flows for query decomposition (SAP generates/queues atomic PRDs), sandboxed code gen/testing (CWA plans/writes/tests Rails code, queues for eval), and dynamic security evals (CSO approves/denies commands with reasons, enforcing duties/privacy); auditing via AgentLog; POC initiation via rake task; cycle completes <1min for simple tasks with traceable logs/green commits; ready for intern access and curriculum ties (e.g., tax sims).

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards (e.g., structured JSON logs via Rails.logger, audit trails for queue enqueues/dequeues with task_id/timestamp/redacted details; include per-queue summary with outcomes like processed/retried/failed).

**Requirements**
- **Functional**:
    - Configure Solid Queue for three dedicated queues: sap_to_cwa (for PRD delegation from SAP to CWA), cwa_to_cso (for command evaluation requests from CWA to CSO), cso_to_cwa (for approvals/denials with reasons from CSO back to CWA). Use Solid Queue jobs to enqueue/dequeue messages as JSON payloads (e.g., {task_id: SecureRandom.uuid, type: "prd", content: "..."}). Include retry logic for Ollama failures (max 3 retries, configurable via job args). Create a base job class (app/jobs/agent_queue_job.rb) for handling queue-specific logic, with .perform(task_id, payload).
    - Error handling: On retry exhaustion, log failure and append to agent_logs/queue_errors_[timestamp].json with details; best-effort per-message: Process independently with final summary log.
- **Non-Functional**:
    - Privacy: Enforce RLS on any queue-related DB access; use Rails 8 native Active Record Encryption for sensitive payload fields.
    - Performance: Process times <5s per message in dev; handle payloads up to 10KB.
    - Rails Guidance: Leverage Rails 8 defaults—add solid_queue to Gemfile if not present; configure in config/solid_queue.yml with queue priorities (critical for cso_to_cwa); use rails generate job to scaffold AgentQueueJob; no new controllers/routes (queue-only). Mock in tests with WebMock/VCR if needed.

**Architectural Context**  
Builds on Rails 8 MVC with PostgreSQL (use Solid Queue's PostgreSQL backend; no new tables beyond defaults; reference existing AgentLog if present for audits). Emphasize local execution: Solid Queue runs in-process or via supervisor (add to Procfile/Procfile.dev). Align with privacy via Rails 8 native Active Record Encryption; no schema changes (reference agreed: User -> PlaidItem -> Account -> Transaction/Position). For RAG/AI: No Ollama calls here, but queues designed to pass knowledge_base/ paths (e.g., 0_AI_THINKING_CONTEXT.md) for future prompts via AiFinancialAdvisor; tie to daily FinancialSnapshotJob JSON blobs if context needed in payloads. Avoid vector DBs—use static docs for simple RAG.

**Previous Clarifications (Integrated from Eric's Feedback)**
1. **DLQ Strategy**: Logging to `agent_logs/queue_errors_[timestamp].json` is sufficient for POC. Add DLQ post-POC if failures >5%.
2. **Payload Encryption**: Use Rails 8 native Active Record Encryption for manual encrypt/decrypt of JSON strings before/after enqueue. No separate `AgentMessage` model yet.
96. **Priority/Polling**: Explicitly define polling intervals and priorities in `config/solid_queue.yml`, especially for `cso_to_cwa`.
96. **AgentPayload**: Define a standard `AgentPayload` helper/concern to ensure `task_id`, `user_id`, and `timestamp` are consistently handled across all three queues.

**Acceptance Criteria**
- Solid Queue supervisor starts with `bin/rails solid_queue:start` and shows all three queues active/empty by default.
- Enqueue a test JSON message from sap_to_cwa in Rails console and confirm processing without errors.
- Simulate Ollama-related error (e.g., raise in job) and verify retries up to 3 times, with logs capturing counts.
- Inspect PostgreSQL (via psql) shows no unencrypted sensitive data in queued payloads.
- Dev env processes queues without config errors; no impact on existing Plaid jobs.
- Queues handle 10KB payloads without truncation/parsing failures.
- Logs include JSON summary (e.g., {queue: "sap_to_cwa", outcome: "processed", retries: 0}).

**Test Cases**
- Unit (Minitest): For AgentQueueJob, test "enqueues JSON to sap_to_cwa" with assert_performed_with; mock storage to verify payload integrity; test retry on raise.
- Integration: Test enqueue/dequeue cycle for sample message; assert Rails.logger output matches format (e.g., "Enqueued to sap_to_cwa at [timestamp]"); use WebMock for stubs (none expected).

**Workflow**  
Junie: Ask questions/build plan first. Pull from feature/multi-agent-poc-epic, branch `feature/multi-agent-poc-epic/queues-setup`. Use Claude Sonnet 4.5. Commit only green code (run minitest, rubocop). Merge to epic branch post-review.

Next steps: Once implemented, review committed code against this PRD using browse_page on GitHub (e.g., diff summary for config/solid_queue.yml). Proceed to PRD 2 after merge?