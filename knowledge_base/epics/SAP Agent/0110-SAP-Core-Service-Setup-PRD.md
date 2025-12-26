### 0110-SAP-Core-Service-Setup-PRD

#### Overview
This PRD defines the core setup of the SAP (Senior Architect and Product Manager) agent as a Rails service to route AI queries for epic/PRD generation and workflow automation, integrating with the standalone SmartProxy for Grok API proxying. This advances the project's vision of efficient, local-first financial data syncing for HNW families by automating manual copy-paste loops in development workflows, enabling Junie to implement features like Plaid investments/transactions/liabilities more reliably.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards, ensuring all SAP query routings, Grok integrations, and errors are logged with timestamps, anonymized details, and traces in agent_logs/sap.log.

#### Requirements
**Functional Requirements:**
- Create a new Rails service class (app/services/sap_agent.rb) that serves as the entrypoint for AI tasks, accepting inputs like query strings (e.g., "Generate PRD for webhook setup") and routing them as JSON payloads to the SmartProxy endpoint (POST to ENV['SMART_PROXY_URL'] + '/proxy/generate').
- Handle query routing: Format incoming queries into Grok-compatible payloads (e.g., { "query": input, "model": "grok-4", "tools": ["web_search"] if needed for live search }), send via HTTP (using Faraday or Net::HTTP), and parse the returned JSON response for further processing.
- Integrate with Grok tools: If the response includes tool calls (e.g., for web_search or x_keyword_search), handle them by re-routing sub-calls through the proxy if necessary, merging results back into the final output (e.g., append search snippets to PRD content).
- Support basic input validation: Ensure queries are non-empty and anonymized (e.g., strip any potential PII); return structured errors (e.g., { "error": "Invalid query" }) if invalid.
- Enqueue async if needed: Use Solid Queue to wrap long-running Grok calls as jobs (e.g., SapProcessJob.perform_later(query)) for non-blocking operation.

**Non-Functional Requirements:**
- Performance: <1s latency for routing (excluding proxy/API time); scale to 5 concurrent queries via queueing.
- Security: Use ENV vars for proxy URL/auth; ensure no sensitive data (e.g., Plaid tokens) in payloads; align with attr_encrypted for any stored intermediates.
- Compatibility: Rails 7+; gems like faraday for HTTP, solid_queue for async.
- Privacy: Anonymize all routed queries; log only redacted versions; no persistent storage of responses beyond workflow needs.

#### Architectural Context
Build as a Rails service object extending AiFinancialAdvisor for consistency with existing AI bridge. Reference MCP and static docs (e.g., 0_AI_THINKING_CONTEXT.md) for query guidelines, but defer full RAG prefixing to PRD-0120. Align with data model (User for auth if needed, but keep SAP stateless initially). Use MVC patterns: No new models/migrations needed; optional controller for testing (e.g., SapController for debug endpoints). Proxy integration via HTTP to localhost:4567; prepare for future Ollama by making routing configurable (e.g., via ENV['AI_PROVIDER']). Test with WebMock/VCR for mocked Grok responses; no vector DB—use simple JSON concat for context when added later.

#### Acceptance Criteria
- SAP service initializes without errors in Rails console (e.g., SapAgent.new.route_query("test query") sends to proxy and returns parsed JSON).
- Valid query routes to SmartProxy, forwards to Grok, and handles tool calls (e.g., web_search returns merged results).
- Invalid query returns error hash without crashing.
- Async enqueue works: Solid Queue job triggers routing on perform.
- No sensitive data in payloads (e.g., manual inspection of logs shows anonymization).
- Service handles concurrent calls via queue without data races.
- ENV config updates (e.g., changing SMART_PROXY_URL) affect routing dynamically.

#### Test Cases
- Unit: RSpec for sap_agent.rb—mock proxy HTTP with WebMock; test routing (assert_equal expected_payload, forwarded_body); verify tool handling (stub response with tool_calls, assert_merged_output).
- Integration: Test full flow with VCR cassette for Grok (sanitized key); enqueue job and assert response parsing; edge cases like tool retry failures or empty queries.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0110-sap-core-service-setup`). Ask questions and build a plan before coding (e.g., "Preferred HTTP gem? How to handle tool call execution—full proxy-side or partial in SAP? Async always or conditional?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.

Next: Generate PRD-0120, or implement this with Junie?