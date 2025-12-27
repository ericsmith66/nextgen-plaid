### 0040-SAP-Grok-Ollama-Routing-Escalation-PRD.md

#### Overview
This PRD implements the `SapAgent::Router` class to manage AI routing between Grok (fast, tool-enabled) and Ollama (local, cost-effective). It enforces token-based thresholds and privacy-first escalations. It also adds a centralized `rake logs:rotate` task for all agent logs.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All routing decisions, token counts, and escalations must be logged in `agent_logs/sap.log`. Include the rationale for each model selection.

#### Requirements
**Functional Requirements:**
- **SapAgent::Router**: Implement as a dedicated class to keep the service layer clean.
- **Routing Thresholds**:
    - **Ollama-first**: If the query is <1K tokens (configurable via `TOKEN_THRESHOLD` ENV) and no search tools are required.
    - **Grok-default**: For tool-heavy queries or complex research.
- **Escalation Logic**:
    - If Ollama fails or times out, escalate to Grok.
    - Log escalation with a specific "Cost/Privacy Escalation" tag.
- **Log Rotation**:
    - Implement `rake logs:rotate` to handle `sap.log`, `smart_proxy.log`, and other agent logs.
    - Rotate daily by appending the date (e.g., `sap.log.2025-12-27`).
    - Schedule via `config/recurring.yml` for 3 AM daily.

**Non-Functional Requirements:**
- Performance: Routing logic <20ms.
- Security: No credential sharing between models.
- Privacy: Always prioritize Ollama for queries containing sensitive data patterns.

#### Architectural Context
Extract routing logic from `SapAgent` into `SapAgent::Router`. Use `AiFinancialAdvisor` for Ollama bridging. Integrate with `config/recurring.yml` for log maintenance.

#### Acceptance Criteria
- `SapAgent::Router` correctly selects Ollama for small, tool-less queries.
- Escalation to Grok works on mock Ollama failure.
- `TOKEN_THRESHOLD` ENV is respected and logged.
- `rake logs:rotate` successfully renames and clears log files.
- `recurring.yml` includes the log rotation task.

#### Test Cases
- Unit (RSpec): `Router` selects correct model based on token count and tool requirements.
- Integration: Test log rotation without file duplication; verify `recurring.yml` syntax.
- System: Submit large query -> verify Grok selection; submit small query -> verify Ollama selection.

#### Workflow
Junie: Use Claude Sonnet 4.5. Pull from master, branch `feature/0040-routing-escalation`. Ask questions about token counting heuristics. Implement in atomic commits. PR to main.