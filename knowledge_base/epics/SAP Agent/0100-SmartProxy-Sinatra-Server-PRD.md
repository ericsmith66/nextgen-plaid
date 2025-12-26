### 0100-SmartProxy-Sinatra-Server-PRD

#### Overview
This PRD defines the setup of a standalone SmartProxy server using Sinatra as a lightweight proxy for Grok (xAI API) calls, enabling secure, anonymized routing of AI queries from the nextgen-plaid app to external Grok tools without direct API exposure in Rails. This supports the project's vision of streamlining AI-assisted PRD generation and workflow automation for HNW financial data syncing, reducing manual copy-paste bottlenecks while maintaining local privacy controls. The proxy must handle Grok's function calling for tools (e.g., web_search, browse_page, x_keyword_search, x_semantic_search) to enable dynamic capabilities like live search, X post analysis, realtime data fetching, and other tool-based enhancements in responses.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards, ensuring all proxy requests/responses/tool calls are logged with timestamps, anonymized payloads, and error traces in a dedicated log file (e.g., smart_proxy.log). If the file is not found, use standard Rails logging conventions (e.g., Logger.new with INFO level, redacted sensitives).

#### Requirements
**Functional Requirements:**
- Implement a Sinatra app (in a new subdir, e.g., `<project root>/smart_proxy/`) with a primary endpoint (POST /proxy/generate) that accepts JSON payloads (e.g., { "query": "Generate PRD for webhook with live search on X", "model": "grok-4", "tools": ["web_search", "x_keyword_search"] }) and forwards them to the Grok API endpoint (https://api.x.ai/v1/chat/completions or equivalent).
- Support function calling: Include tool definitions in forwarded payloads (e.g., as an array of tool specs like { "type": "function", "function": { "name": "web_search", "description": "Search the web", "parameters": {...} }}); if the Grok response includes a tool call (e.g., in "choices[0].message.tool_calls" with function name/arguments), the proxy should automatically execute supported tools locally if needed (e.g., simulate or proxy sub-calls for web_search via internal HTTP) or return the call for SAP to handle, enabling live search/X analysis without additional loops.
- Anonymize requests: Strip any sensitive data (e.g., PII, real financial info) from payloads and tool arguments before forwarding; add headers for authentication using ENV['GROK_API_KEY'].
- Handle responses: Parse Grok JSON responses (including tool results if executed) and return them unmodified to the caller (e.g., Rails SAP service), merging any tool outputs back into the response structure.
- Support basic error handling: Retry on 429/5xx errors (up to 3 times with exponential backoff); return structured errors (e.g., { "error": "API timeout" }); log failed tool calls separately.
- Run as a standalone server: Use Puma or Thin for production-like serving; configurable port (default 4567) via ENV['SMART_PROXY_PORT'].

**Non-Functional Requirements:**
- Performance: <500ms latency for proxy calls (excluding API/tool execution time); handle up to 10 concurrent requests, including parallel tool calls.
- Security: Require API key auth on the proxy endpoint (e.g., via HTTP Basic or bearer token from ENV['PROXY_AUTH_TOKEN']); run on localhost only for local dev; ensure tool executions (e.g., web_search) do not expose sensitive data.
- Compatibility: Ruby 3.2+; minimal gems (sinatra, json, faraday or net-http for API/tool sub-calls).
- Privacy: No storage of requests/responses/tool results beyond logs; ensure no cloud leakage aligns with local-first vision; anonymize tool queries (e.g., generalize financial terms in search params).

#### Architectural Context
Integrate loosely with Rails via HTTP calls from AiFinancialAdvisor service—no direct coupling. Use ENV vars for config (e.g., in .env.local) to avoid hardcoding. Reference static docs like 0_AI_THINKING_CONTEXT.md for prompt guidelines, but no RAG here (defer to SAP). Align with agreed schema/privacy (e.g., no Plaid data in proxies or tool calls). For future, design extensible routes/endpoints for adding Ollama/other AIs (e.g., POST /proxy/ollama). Use Rails generators sparingly (none needed here); focus on simple Sinatra structure (app.rb for routes/endpoints, config.ru for rackup). Handle tool executions modularly (e.g., a tools/ dir with handlers for web_search via Faraday to search APIs if Grok requires proxy-side execution).

#### Acceptance Criteria
- Proxy server starts via `rackup` or `ruby app.rb` on localhost:4567 without errors.
- POST /proxy/generate with valid payload (including tools array) forwards to Grok API and returns expected JSON response (e.g., generated text with tool results if called).
- If payload includes tools, proxy correctly includes definitions in API call; simulates/handles a tool response (e.g., web_search returns mock/snippet results merged into final output).
- Invalid requests (e.g., missing key, unsupported tool) return 401/400 with error JSON.
- Retries occur on simulated 429 errors; logs capture all attempts and tool executions.
- No sensitive data (e.g., mock financial JSON) appears in forwarded payloads, tool args, or logs.
- Server handles concurrent curls (e.g., 5 simultaneous with tool calls) without crashes.
- ENV config works: Changing GROK_API_KEY or port updates behavior; basic health check (GET /health) returns { "status": "ok" }.

#### Test Cases
- Unit: RSpec (in spec/) for endpoint logic—mock Grok API with WebMock; test tool inclusion/anonymization (e.g., assert_match(/tools/, forwarded_body); assert_no_match(/PII/, forwarded_body)); verify tool call handling (stub response with tool_calls, assert merged output).
- Integration: Simulate full call via curl or Faraday in a test script; VCR cassettes for real Grok responses (sanitized keys, including tool executions like web_search).
- Edge: Test retries with stubbed failures; invalid payloads/tools; large responses (>10KB); parallel tool calls (e.g., multiple searches in one response).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0100-smartproxy-sinatra-server`). Ask questions and build a plan before coding (e.g., "What tool definitions to include by default? How to handle tool execution—proxy-side or return to SAP? Any gem preferences for HTTP?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.

Next: Implement this with Junie, or generate 0110-SAP-Core-Service-Setup-PRD?