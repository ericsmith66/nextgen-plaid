### PRD AGENT-05: Add AgentLog Model and Rake Task for POC Initiation and Auditing

**Overview**  
Introduce an AgentLog model for auditing multi-agent interactions and a rake task to initiate POC flows via SAP, enabling traceable, independent agent runs with human entry limited to queries/escalations. This supports HNW privacy by logging decisions without exposing financial data, aligning with the virtual family office vision for auditable AI-driven stewardship training.

**Epic Summary**: This epic implements a POC for three-persona (SAP, CWA, CSO) interactions via asynchronous queues, allowing agents to run independently with limited human input (e.g., via SAP queries or CSO escalations). It proves the multi-agent foundation for expanding to full personas (e.g., CFO, Tax Attorney) in the AI tutor/internship system, using local Ollama for privacy-focused decisions. Other PRDs in this epic: (AGENT-01) Solid Queue setup for agent communication; (AGENT-02) SAP service for query/PRD gen and delegation; (AGENT-03) CWA service for PRD review/code gen and CSO queuing; (AGENT-04) CSO service for command eval and feedback.

**End of Epic Capabilities**: Full asynchronous agent flows for query decomposition (SAP generates/queues atomic PRDs), sandboxed code gen/testing (CWA plans/writes/tests Rails code, queues for eval), and dynamic security evals (CSO approves/denies commands with reasons, enforcing duties/privacy); auditing via AgentLog; POC initiation via rake task; cycle completes <1min for simple tasks with traceable logs/green commits; ready for intern access and curriculum ties (e.g., tax sims).

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards (e.g., structured JSON logs via Rails.logger, audit trails for rake/init with task_id/timestamp/redacted details; include per-run summary with outcomes like steps_logged/escalations_sent).

**Requirements**
- **Functional**:
    - Generate AgentLog model (fields: task_id:string:index, persona:string (e.g., 'SAP'), action:string (e.g., 'decompose'), details:text, timestamp:datetime default now, user_id:integer:foreign_key). Add validations (presence: task_id/action, length: details <10KB).
    - Auto-log in services: Extend SAP/CWA/CSO with after_perform hooks to create AgentLog (e.g., details as JSON {input: "...", output: "..."}).
    - Rake task: `rake agents:poc_task[query,user_id=1]` to call SapAgent.call(query, user_id), triggering full flow; log start/end.
    - Error handling: On rake fail (e.g., invalid query), log to AgentLog with reason; append full traces to agent_logs/poc_errors_[timestamp].json.
    - Idempotency: Unique index on (task_id, persona, action); upsert for updates.
- **Non-Functional**:
    - Privacy: Encrypt details via Rails 8 native Active Record Encryption; apply RLS (user owns logs).
    - Performance: Log creation <1s; rake handles queries up to 500 chars.
    - Rails Guidance: Use rails g model AgentLog; add migration for columns/indexes/foreign_keys; service hooks via callbacks; rake in lib/tasks/agents.rake. Mock in tests with WebMock/VCR if Ollama/email involved (defer).

**Architectural Context**  
Builds on Rails 8 MVC with PostgreSQL (add table with RLS; reference User for foreign_key). Integrate with Solid Queue (from AGENT-01) for log triggers in jobs; tie to services (AGENT-02/03/04) for auto-logging. Align with privacy (encrypted logs, local-only); no Ollama here, but prepare for RAG audits (append `knowledge_base/` paths if needed). Avoid vector DBs—use JSON from FinancialSnapshotJob for context if extended (defer for POC).

**Previous Clarifications (Integrated from Eric's Feedback)**
8. **Storage**: Store redacted/truncated prompt/response in `AgentLog` for privacy. Full details go to optional `debug_logs/`.
9. **Rake Execution**: Asynchronous initiation (trigger SAP and exit).
10. **Encryption**: Use Rails 8 native Active Record Encryption for `AgentLog` details. No separate `Query` model.
100. **Visibility**: Add STDOUT streaming to the rake task (e.g., tail `AgentLog` or query on completion) for real-time visibility.

**Acceptance Criteria**
- AgentLog model migrates/validates; creates entries with encrypted details.
- Services (SAP/CWA/CSO) auto-log on perform (verify via console: count increases).
- Rake `agents:poc_task["test query",1]` triggers SAP, logs start/end/full cycle (>3 entries).
- On error (e.g., invalid query), logs reason without crash; viewable via console query.
- RLS: Non-owner can't access logs; encryption verified (raw DB cipher).
- Handles no user_id (default 1); logs JSON-structured details.
- Full POC cycle generates 5+ logs covering all personas.

**Test Cases**
- Unit (Minitest): For AgentLog, test validations/uniqueness/encryption; mock service hook to create log.
- Integration: Test rake invocation with queue mocks; assert AgentLog.count changes; verify logs match JSON (e.g., {action: "decompose", outcome: "success"}); test error paths with raises.

**Workflow**  
Junie: Ask questions/build plan first. Pull from feature/multi-agent-poc-epic, branch `feature/multi-agent-poc-epic/agent-log-rake`. Use Claude Sonnet 4.5. Commit only green code (run minitest, rubocop). Merge to epic branch post-review.

Next steps: Once implemented, review committed code against this PRD using browse_page on GitHub (e.g., diff summary for db/migrate/*_create_agent_logs.rb). Merge epic to main after all PRDs?