### 0030-SAP-SmartProxy-Tool-Integration-PRD.md

#### Overview
This PRD enhances the `SmartProxy` (Sinatra-based) with tool integrations for `web_search` and `x_keyword_search`. It introduces a synthesis layer that aggregates results into a single JSON response with a **Confidence Score** (0-1). It also ensures strict session isolation using request-local IDs.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All tool calls, session IDs, and confidence scores must be logged in `agent_logs/smart_proxy.log`.

#### Requirements
**Functional Requirements:**
- **Tool Wrappers**: Add Faraday-based clients for:
    - `web_search(query, num_results)`
    - `x_keyword_search(query, limit, mode)`
- **Session Isolation Middleware**:
    - Use `SecureRandom.uuid` per request.
    - Pass UUID to Faraday headers.
    - Ensure no environment variable bleed between concurrent requests.
- **Synthesis & Confidence Score**:
    - Aggregate results into a single JSON: `{"confidence": 0.85, "web_results": [...], "x_results": [...] }`.
    - Calculate confidence based on result relevance and match strength.
- **Error Handling**: Log failures per tool; if confidence is <0.5, trigger a single re-query attempt with a refined search string.

**Non-Functional Requirements:**
- Performance: Tool aggregation <1s.
- Security: Use dedicated API keys (e.g., `GROK_API_KEY_SAP`) isolated from the main Rails app.
- Privacy: No persistent storage of search results.

#### Architectural Context
Build on the existing Sinatra server in `smart_proxy/`. Integrate with `SapAgent::ArtifactCommand` via a Faraday client in the Rails app.

#### Acceptance Criteria
- `SmartProxy` returns a synthesized JSON response with a Confidence Score.
- Concurrent requests are isolated via unique session UUIDs (verified in logs).
- Low-confidence results (<0.5) trigger a re-query.
- Aggregated output is correctly parsed by `SapAgent` and injected into the prompt.

#### Test Cases
- Unit (RSpec): Faraday wrappers handle mock success/failure; Confidence Score calculation logic.
- Integration: Concurrent request simulation testing isolation; VCR for aggregated tool calls.
- System: Submit research-heavy query -> verify aggregated JSON in logs with score >0.7.

#### Workflow
Junie: Use Claude Sonnet 4.5. Pull from master, branch `feature/0030-smartproxy-tools`. Ask questions about confidence score heuristics. Implement in atomic commits. PR to main.
