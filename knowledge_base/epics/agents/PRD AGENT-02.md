### PRD AGENT-02: Implement SAP Agent Service for Query Decomposition and Delegation

**Overview**  
Add the SAP (Senior Architect and Product Manager) service to decompose human queries into atomic PRDs and delegate via queue to the CWA (Code Writer Agent), enabling independent agent flows in the three-persona POC and aligning with the virtual family office vision by automating requirement handling for intern training features. This supports HNW families in generating precise, Rails-tailored specs for financial data features (e.g., Plaid integrations) without manual PRD drafting.

**Epic Summary**: This epic implements a POC for three-persona (SAP, CWA, CSO) interactions via asynchronous queues, allowing agents to run independently with limited human input (e.g., via SAP queries or CSO escalations). It proves the multi-agent foundation for expanding to full personas (e.g., CFO, Tax Attorney) in the AI tutor/internship system, using local Ollama for privacy-focused decisions. Other PRDs in this epic: (AGENT-01) Solid Queue setup for agent communication; (AGENT-03) CWA service for PRD review/code gen and CSO queuing; (AGENT-04) CSO service for command eval and feedback; (AGENT-05) AgentLog model and rake task for auditing/initiation.

**End of Epic Capabilities**: Full asynchronous agent flows for query decomposition (SAP generates/queues atomic PRDs), sandboxed code gen/testing (CWA plans/writes/tests Rails code, queues for eval), and dynamic security evals (CSO approves/denies commands with reasons, enforcing duties/privacy); auditing via AgentLog; POC initiation via rake task; cycle completes <1min for simple tasks with traceable logs/green commits; ready for intern access and curriculum ties (e.g., tax sims).

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards (e.g., structured JSON logs via Rails.logger, audit trails for decompositions with user_id/timestamp/redacted query details; include per-query summary with outcomes like generated_prd_length/success/queued_to_cwa).

**Requirements**
- **Functional**:
    - Create app/services/sap_agent.rb as a service object that accepts a string query (e.g., "Add Transaction category enum") and optional user_id (integer, default to current_user.id if in context). Use local Ollama 70B via AiFinancialAdvisor to generate a concise atomic PRD in Markdown format (<1500 words, structured with sections like Overview, Requirements, etc.). Prompt engineering: Start with vision context from knowledge_base/0_AI_THINKING_CONTEXT.md + PRODUCT_REQUIREMENTS.md appended as RAG chunks; include Rails-specific guidance (e.g., MVC patterns, migrations, tests).
    - After generation, enqueue the PRD to sap_to_cwa queue as JSON payload {task_id: SecureRandom.uuid, type: "prd", content: prd_md, user_id: id}.
    - Error handling: If Ollama fails (e.g., timeout), retry once and log; invalid query (e.g., empty/too long >500 chars) → raise ArgumentError with message; append error details to agent_logs/sap_errors_[timestamp].json.
    - Idempotency: No dedupe needed (queries unique); but log query hash (MD5) for tracing.
- **Non-Functional**:
    - Performance: PRD generation <10s in dev; handle queries up to 500 chars; use streaming if Ollama supports for long responses.
    - Privacy: Encrypt any sensitive query parts (e.g., via Rails 8 native Active Record Encryption if user_id tied to data); ensure RAG chunks exclude real financials (use mocks).
    - Rails Guidance: Follow service pattern (.call method); integrate with existing AiFinancialAdvisor (HTTP to localhost:11434); no new models/migrations; use Rails.logger for structured output. Mock Ollama in tests with VCR.

**Architectural Context**  
Builds on Rails 8 MVC with PostgreSQL (no schema changes; reference User for optional auth scoping via RLS). Leverage existing AiFinancialAdvisor for Ollama bridge (70B for fast PRD gen); RAG via static knowledge_base/ docs appended to prompts for context-aware outputs (e.g., tie to Plaid schema: User -> PlaidItem -> Account -> Transaction/Position). Align with privacy (local-only Ollama, no cloud); integrate with Solid Queue (from AGENT-01) for enqueue. Avoid vector DBs—use JSON snapshots from FinancialSnapshotJob if query needs financial context (defer for POC).

**Previous Clarifications (Integrated from Eric's Feedback)**
3. **RAG Implementation**: Use existing `AiFinancialAdvisor` utility for appending static files to prompts (via `File.read`). No new scraper needed.
10. **Encryption**: Use `AgentLog` (AGENT-05) to encrypt details. Manual encryption for query parts in payloads/logs using Rails 8 native helpers. No separate `Query` model.
97. **Context Window**: Cap RAG chunks at 4K tokens in prompts to avoid truncation.
97. **Error Handling**: Implement a shared `AgentErrorHandler` module for file-based error logging across all personas.

**Acceptance Criteria**
- SAP service callable via Rails console: SapAgent.call("test query", user_id: 1) generates valid MD PRD string with required sections.
- Enqueues to sap_to_cwa with JSON payload including uuid, type: "prd", full content, and user_id.
- PRD content ties to vision (e.g., mentions HNW privacy) and includes Rails guidance (e.g., migrations/tests).
- Handles invalid query by raising error without enqueue; logs details in agent_logs/.
- RAG integration: Prompt logs show appended knowledge_base/ chunks.
- No cloud calls: Verify via network inspect; Ollama response parsed correctly.
- Queue payload <10KB; handles long PRDs without truncation.

**Test Cases**
- Unit (Minitest): For SapAgent, stub AiFinancialAdvisor response; assert PRD format matches regex for sections (e.g., /Overview/); test enqueue with assert_performed_with; mock invalid query to raise/log.
- Integration: Test full .call + enqueue; use VCR for Ollama HTTP mocks; verify logs match JSON structure (e.g., {query_hash: "...", outcome: "success"}); test with/without user_id.

**Workflow**  
Junie: Ask questions/build plan first. Pull from feature/multi-agent-poc-epic, branch `feature/multi-agent-poc-epic/sap-service`. Use Claude Sonnet 4.5. Commit only green code (run minitest, rubocop). Merge to epic branch post-review.

Next steps: Once implemented, review committed code against this PRD using browse_page on GitHub (e.g., diff summary for app/services/sap_agent.rb). Proceed to PRD AGENT-03 after merge?