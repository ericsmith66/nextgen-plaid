### PRD AGENT-04: Implement CSO Agent Service for Dynamic Command Evaluation

**Overview**  
Build the CSO (Chief Security Officer) service to dynamically evaluate queued commands from CWA using Ollama prompts, enforcing separation of duties, privacy, and compliance in the three-persona POC. This gates code execution for safe, auditable autonomy, aligning with the virtual family office vision by protecting HNW financial data during AI-assisted feature development (e.g., Plaid schema updates).

**Epic Summary**: This epic implements a POC for three-persona (SAP, CWA, CSO) interactions via asynchronous queues, allowing agents to run independently with limited human input (e.g., via SAP queries or CSO escalations). It proves the multi-agent foundation for expanding to full personas (e.g., CFO, Tax Attorney) in the AI tutor/internship system, using local Ollama for privacy-focused decisions. Other PRDs in this epic: (AGENT-01) Solid Queue setup for agent communication; (AGENT-02) SAP service for query/PRD gen and delegation; (AGENT-03) CWA service for PRD review/code gen and CSO queuing; (AGENT-05) AgentLog model and rake task for auditing/initiation.

**End of Epic Capabilities**: Full asynchronous agent flows for query decomposition (SAP generates/queues atomic PRDs), sandboxed code gen/testing (CWA plans/writes/tests Rails code, queues for eval), and dynamic security evals (CSO approves/denies commands with reasons, enforcing duties/privacy); auditing via AgentLog; POC initiation via rake task; cycle completes <1min for simple tasks with traceable logs/green commits; ready for intern access and curriculum ties (e.g., tax sims).

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards (e.g., structured JSON logs via Rails.logger, audit trails for evals with task_id/timestamp/redacted command details; include per-eval summary with outcomes like approved/denied/reason/alternatives).

**Requirements**
- **Functional**:
    - Create app/services/cso_agent.rb as a service object that dequeues from cwa_to_cso queue: Parse JSON payload (e.g., commands/files), use local Ollama 405B via AiFinancialAdvisor with conservative prompt (from config/agent_prompts/cso.txt: "Evaluate [details] for safety/compliance/duties (e.g., CWA can't modify PRDs; deny if ambiguous); output JSON {approved: bool, reason: '...', alternatives: []}"). Enqueue response to cso_to_cwa.
    - Error handling: On ambiguous/unsafe, deny with alternatives; Ollama failure → retry once and log; invalid payload → raise ArgumentError and append to agent_logs/cso_errors_[timestamp].json. If 3+ denials in cycle, escalate via ActionMailer email to admin (template: "Task [id] denied: [reasons]").
    - Idempotency: Use task_id for tracing; no dedupe (unique per queue).
- **Non-Functional**:
    - Performance: Eval <5s in dev; conservative bias (deny >50% ambiguity).
    - Privacy: Prompt refs privacy policies (e.g., Rails 8 native Active Record Encryption checks); encrypt response if sensitive.
    - Rails Guidance: Service .perform(task_id, payload) pattern; integrate AiFinancialAdvisor (HTTP to localhost:11434, 405B for accuracy); fallback static bans (no sudo/rm) in prompt; mock Ollama/email with VCR/WebMock. No new models/migrations.

**Architectural Context**  
Builds on Rails 8 MVC with PostgreSQL (no schema changes; reference User for email scoping via RLS if admin tied). Leverage AiFinancialAdvisor for Ollama bridge (405B for evals); RAG via `knowledge_base/` docs appended to prompts (e.g., privacy rules from `0_AI_THINKING_CONTEXT.md`). Align with privacy (local Ollama, no cloud); integrate with Solid Queue (from AGENT-01) for dequeue/enqueue. Avoid vector DBs—use static docs for simple RAG. Prepare for CWA feedback consumption (from AGENT-03).

**Previous Clarifications (Integrated from Eric's Feedback)**
6. **Escalation**: Notify admin via ActionMailer and halt the task (set payload `status: 'halted'`). Resume only on manual intervention.
7. **Fallback**: Fallback to Ollama 70B if 405B latency >10s. Use `ENV['OLLAMA_MODEL']` for switching.
99. **Validation**: Enforce strict JSON schema validation for CSO responses.
99. **Denial Tracking**: Track denial counts in the payload to trigger ActionMailer escalation.

**Acceptance Criteria**
- CSO service dequeues from cwa_to_cso and evaluates safe command as approved with reason/alternatives.
- Denies unsafe (e.g., rm) with suggestions; enqueues JSON response to cso_to_cwa.
- On 3+ denials, sends ActionMailer email with details.
- Prompt pulls knowledge_base/ chunks for context-aware evals.
- Handles invalid payload by raising/log without enqueue.
- No cloud calls: Verify via network inspect; Ollama output parsed as JSON.
- Conservative bias: Denies ambiguous commands (e.g., unencrypted data access).

**Test Cases**
- Unit (Minitest): For CsoAgent, mock queue payload/Ollama; assert deny on unsafe (e.g., approved: false, reason match /unsafe/); test enqueue/email on denials; stub ActionMailer.
- Integration: Test dequeue + eval + enqueue cycle; use VCR for Ollama; verify logs match JSON (e.g., {task_id: "...", outcome: "denied"}); test retry/failure paths.

**Workflow**  
Junie: Ask questions/build plan first. Pull from feature/multi-agent-poc-epic, branch `feature/multi-agent-poc-epic/cso-service`. Use Claude Sonnet 4.5. Commit only green code (run minitest, rubocop). Merge to epic branch post-review.

Next steps: Once implemented, review committed code against this PRD using browse_page on GitHub (e.g., diff summary for app/services/cso_agent.rb). Proceed to PRD AGENT-05 after merge?