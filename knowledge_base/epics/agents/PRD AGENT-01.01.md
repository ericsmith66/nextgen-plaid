### PRD AGENT-01.1: Integrate and Augment SmartProxy for AI Routing

**Overview**  
Integrate SmartProxy as a local AI router for AiFinancialAdvisor, defaulting to Ollama (70B/405B) for privacy and escalating to Grok API on "#Hey Grok!" in prompts. Augment for Grok tools (realtime search via web_search tool), enabling SAP/CSO realtime research (e.g., tax updates) while keeping financial data local. Add as submodule in nextgen-plaid for Junie to maintain/modify code.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards (e.g., structured JSON logs via Rails.logger, audit trails for proxy calls with task_id/timestamp/redacted prompt details; include per-call summary with outcomes like backend_used/escalated/tool_invoked).

**Requirements**
- **Functional**:
    - Add SmartProxy as submodule: `git submodule add https://github.com/ericsmith66/SmartProxy lib/smart_proxy`; configure to run locally (port 11435) with Ollama default, Grok escalation on "#Hey Grok!".
    - Augment ai_proxy.rb: Parse tool calls in escalated prompts (e.g., if "web_search" detected, invoke Grok API with tool param; handle responses with search results). Support realtime search: On prompts like "#Hey Grok! search [query]", return enriched completion.
    - Update AiFinancialAdvisor: Change endpoint to http://localhost:11435/v1/chat/completions; test escalation.
    - Error handling: Fallback to Ollama on Grok fail; log escalations to lib/smart_proxy/logs/; invalid tools → raise ArgumentError and append to agent_logs/proxy_errors_[timestamp].json.
    - Idempotency: Log call hash (MD5 of prompt) for tracing; no dedupe (calls unique).
- **Non-Functional**:
    - Performance: Routing <1s added latency; local default for 95% calls.
    - Privacy: No tools on Ollama; encrypt API keys in .env; redact prompts in logs.
    - Rails Guidance: Run as separate process (Procfile: smart_proxy: cd lib/smart_proxy && rackup -p 11435); no new models/migrations; mock proxy in tests with VCR/WebMock. Use Sinatra for proxy mods; bundle install in submodule.

**Architectural Context**  
Builds on Rails 8 MVC with PostgreSQL (no schema changes). Ties to AiFinancialAdvisor for all AI calls (e.g., SAP prompts); submodule allows Junie direct code interaction (e.g., extend routing). Align with privacy (local Ollama default, explicit Grok); integrate with Solid Queue (AGENT-01) for agent flows. Avoid vector DBs—use for RAG prompts only.

**Previous Clarifications (Integrated from Junie's Questions)**  
None for this PRD (new feature; if questions arise during plan, integrate in future revisions).

**Acceptance Criteria**
- Submodule added/committed; runs locally with Grok key via `cd lib/smart_proxy && rackup`.
- AiFinancialAdvisor routes to 11435; default Ollama works.
- Escalated prompt with "#Hey Grok! search test" invokes tool, returns results.
- Logs show backend/tool usage; no unredacted sensitive data.
- Handles Grok fail by fallback to Ollama.
- Proxy mods (tool support) tested via curl.
- No cloud unless escalated: Verify network inspect.

**Test Cases**
- Unit (Minitest): Stub proxy responses; assert routing/escalation; test tool payload parse.
- Integration: Test AiFinancialAdvisor call with/without keyword; VCR for HTTP; verify logs match JSON (e.g., {backend: "grok", tool: "web_search"}).

**Workflow**  
Junie: Ask questions/build plan first. Pull from feature/multi-agent-poc-epic, branch `feature/multi-agent-poc-epic/smart-proxy`. Use Claude Sonnet 4.5. Commit only green code (run minitest, rubocop). Merge to epic branch post-review.

Next steps: Implement AGENT-01 first; proceed to AGENT-01.1 after?