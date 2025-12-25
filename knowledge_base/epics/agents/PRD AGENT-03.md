### PRD AGENT-03: Implement CWA Agent Service for Code Generation and CSO Queuing

**Overview**  
Develop the CWA (Code Writer Agent) service to process queued PRDs from SAP, generate Rails code in a sandbox, run tests, and queue command details to CSO for evaluation, supporting POC independence and the goal of autonomous code shipping for wealth stewardship tools. This enables HNW families to safely iterate on financial features (e.g., Plaid schema extensions) with AI-assisted implementation.

**Epic Summary**: This epic implements a POC for three-persona (SAP, CWA, CSO) interactions via asynchronous queues, allowing agents to run independently with limited human input (e.g., via SAP queries or CSO escalations). It proves the multi-agent foundation for expanding to full personas (e.g., CFO, Tax Attorney) in the AI tutor/internship system, using local Ollama for privacy-focused decisions. Other PRDs in this epic: (AGENT-01) Solid Queue setup for agent communication; (AGENT-02) SAP service for query/PRD gen and delegation; (AGENT-04) CSO service for command eval and feedback; (AGENT-05) AgentLog model and rake task for auditing/initiation.

**End of Epic Capabilities**: Full asynchronous agent flows for query decomposition (SAP generates/queues atomic PRDs), sandboxed code gen/testing (CWA plans/writes/tests Rails code, queues for eval), and dynamic security evals (CSO approves/denies commands with reasons, enforcing duties/privacy); auditing via AgentLog; POC initiation via rake task; cycle completes <1min for simple tasks with traceable logs/green commits; ready for intern access and curriculum ties (e.g., tax sims).

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards (e.g., structured JSON logs via Rails.logger, audit trails for code gens with task_id/timestamp/redacted PRD details; include per-task summary with outcomes like files_generated/test_results/queued_to_cso).

**Requirements**
- **Functional**:
    - Create app/services/cwa_agent.rb as a service object that dequeues from sap_to_cwa queue: Parse JSON payload (e.g., prd_content), use local Ollama 70B via AiFinancialAdvisor to plan/write code (e.g., models/migrations/controllers/tests based on PRD). Execute in isolated sandbox (`tmp/agent_sandbox/` directory, subprocess for rails g/migrate/test). If Minitest green, queue command details to cwa_to_cso as JSON {task_id: uuid, commands: ["rails g model..."], files: {path: content,...}, test_output: "..."}.
    - Error handling: On test failure, log details and requeue to sap_to_cwa with feedback (e.g., {type: "revision", issues: "..."}); Ollama timeout → retry once; invalid PRD → raise ArgumentError and log to agent_logs/cwa_errors_[timestamp].json.
    - Idempotency: Use task_id for tracing; no dedupe (unique per queue).
- **Non-Functional**:
    - Performance: Code gen/execution <30s in dev; sandbox limits to 100MB/10s CPU.
    - Privacy: Sandbox isolates from main repo/DB; encrypt file contents in queue if sensitive (via Rails 8 native Active Record Encryption).
    - Rails Guidance: Service .perform(task_id, payload) pattern; use subprocess.call for rails commands (e.g., ['bin/rails', 'g', 'migration...']); Minitest only (no RSpec); mock Ollama/tests with VCR/WebMock. No new models/migrations; cleanup sandbox post-run.

**Architectural Context**  
Builds on Rails 8 MVC with PostgreSQL (no schema changes; reference User for scoping via RLS if user_id in payload). Leverage AiFinancialAdvisor for Ollama bridge (70B for code tasks); RAG via `knowledge_base/` docs appended to prompts (e.g., schema refs from `PRODUCT_REQUIREMENTS.md`). Align with privacy (local Ollama/sandbox, no cloud); integrate with Solid Queue (from AGENT-01) for dequeue/enqueue. Avoid vector DBs—use JSON from FinancialSnapshotJob if PRD needs context (defer for POC). Prepare for CSO feedback loop (from AGENT-04).

**Previous Clarifications (Integrated from Eric's Feedback)**
4. **Sandbox Dependencies**: No `bundle install` allowed in sandbox. If new gems are needed, CWA flags them in feedback to SAP for human intervention.
5. **Knowledge Base**: Use existing `knowledge_base/` docs (e.g., `PRODUCT_REQUIREMENTS.md`) via RAG in prompts.
81. **Sandbox Execution**: Use `tmp/agent_sandbox/` (no Docker). Limit to read-only schema refs.
98. **Sandbox Database**: Use in-memory SQLite for sandbox database (via `config/sandbox_database.yml`).
98. **Revision Loop**: Add `iteration_limit: 3` to payload to prevent infinite "hallucination loops".

**Acceptance Criteria**
- CWA service dequeues from sap_to_cwa and generates code files/tests in temp sandbox for mock PRD (e.g., simple migration).
- Runs Minitest successfully; enqueues to cwa_to_cso only on green with JSON including commands/files/output.
- On test failure, requeues to sap_to_cwa with revision feedback.
- Sandbox cleans up post-run; no main repo changes.
- Logs show full Ollama prompt/response and test results in JSON.
- Handles invalid payload by raising/log without enqueue.
- RAG: Prompts include knowledge_base/ chunks for context.

**Test Cases**
- Unit (Minitest): For CwaAgent, mock queue payload/Ollama; assert sandbox files created (e.g., migration.rb); test enqueue on green, requeue on red; mock subprocess for rails g/test.
- Integration: Test dequeue + gen + enqueue cycle; use VCR for Ollama; verify logs match JSON (e.g., {task_id: "...", outcome: "green_queued"}); test failure paths.

**Workflow**  
Junie: Ask questions/build plan first. Pull from feature/multi-agent-poc-epic, branch `feature/multi-agent-poc-epic/cwa-service`. Use Claude Sonnet 4.5. Commit only green code (run minitest, rubocop). Merge to epic branch post-review.

Next steps: Once implemented, review committed code against this PRD using browse_page on GitHub (e.g., diff summary for app/services/cwa_agent.rb). Proceed to PRD AGENT-04 after merge?