Revised Epic 1: SAP Core & Tools (AGENT-02A)
Overview: Builds on partial SAP implementation from PRD 0110 (merged commit 026c09f, app/services/sap_agent.rb exists with basic routing). Addresses insufficient prompts by externalizing structured atomic formats via a unified ArtifactCommand engine and a Strategy pattern (Backlog, Epic, PRD). Integrates web_search/x_keyword_search via SmartProxy with Confidence Scores and isolation middleware. Defaults to Grok for speed, escalating from Ollama (via AiFinancialAdvisor) for cost/privacy. Ties to vision via MCP.md SSOT.

Architecture:
- Base Engine: SapAgent::ArtifactCommand (handles prompt load, tool calls, template injection, validation/retry).
- Strategies: BacklogStrategy, EpicStrategy, PrdStrategy (encapsulate type-specific logic).
- Templates: ERB skeletons in templates/ for structural enforcement and Ruby-pre-populated metadata.
- Validation: Pre-storage regex/schema checks with self-correction (max 2 attempts).
- Router: SapAgent::Router for Grok/Ollama escalation logic.

Atomic PRDs:

0010-Backlog-PRD.md: Implements BacklogStrategy for ArtifactCommand; manages backlog.json (Ruby generates incremental IDs, validates JSON); includes pruning logic for stale items.
0012-Epics-PRD.md: Implements EpicStrategy for ArtifactCommand; generates epic-specific overviews and groups PRDs using epic.md.erb template.
0015-PRDs-PRD.md: Implements PrdStrategy for ArtifactCommand; generates atomic PRDs using prd.md.erb template (enforcing 5-8 AC bullets).

0020-SAP-Enhanced-Prompt-Externalization-PRD.md: Externalizes SAP's system prompt to config/agent_prompts/sap_system.md; mandates ERB templates for skeletons; enforces vision tie-in via MCP.md.
0030-SAP-SmartProxy-Tool-Integration-PRD.md: Enhances SmartProxy with Confidence Scores (0-1), isolation middleware (request IDs), and Faraday wrappers for research tools.
0040-SAP-Grok-Ollama-Routing-Escalation-PRD.md: Implements SapAgent::Router with cost/token thresholds (<1K tokens for Ollama); adds rake logs:rotate for daily cleanup.

Success Criteria: Generates 3 pilot PRDs matching atomic format (<30s via Grok); tools pull external data with Confidence Score >0.7; 100% test coverage on routing and validation retries.
Capabilities Built: Functional SAP brain with structural enforcement; isolated tool calls with research synthesis; prompt-enforced alignment to Rails MVC/privacy mandates.