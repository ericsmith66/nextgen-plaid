### 0110-SAP-Core-Service-Setup-PRD

#### Overview
This PRD defines the core setup of the SAP (Senior Architect and Product Manager) agent as a Rails service using a **Unified Command Pattern**. It routes AI queries for generation, QA, and debugging, integrating with the standalone SmartProxy. This merges requirements for QA loops and debugging assistance into a single core service architecture, streamlining AI-assisted development for HNW financial data syncing.

#### Unified Command Pattern
SAP shall implement a base `SapAgent::Command` class with specialized subclasses:
- `SapAgent::GenerateCommand`: For PRD/Epic generation (incorporating RAG from 0120).
- `SapAgent::QaCommand`: For handling Junie's questions and review loops.
- `SapAgent::DebugCommand`: For log analysis and fix proposals.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards. All commands must log their lifecycle (start, proxy call, parsing, completion) to `agent_logs/sap.log`.

#### Definition of Done (DoD)
- **Unified Logic**: All AI interactions must inherit from `SapAgent::Command`.
- **Testing**: 
  - RSpec coverage for all command subclasses.
  - VCR/WebMock for proxy interaction tests.
- **Error Handling**: Standardized error response format across all commands.
- **Logging**: Detailed command execution logs with timing and status.

#### Requirements
**Functional Requirements:**
- Create `app/services/sap_agent/command.rb` (Base) and subclasses for `Generate`, `Qa`, and `Debug`.
- Entrypoint: `SapAgent.process(query_type, payload)` which dispatches to the appropriate command.
- Routing: Format JSON payloads for SmartProxy (POST to `ENV['SMART_PROXY_URL']`).
- QA Loop Handling: Parse Junie's questions/reviews and route for resolution.
- Debugging Assistance: Pull recent log snippets (e.g., from `log/*.log`), format for AI analysis, and return fix proposals.
- Integrate with Grok tools: Handle tool calls (web_search, etc.) via proxy-side or SAP-side resolution.
- Support basic input validation and anonymization.
- Enqueue async: Use Solid Queue (`SapProcessJob`) to wrap command execution.

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