### 0020-SAP-Enhanced-Prompt-Externalization-PRD.md

#### Overview
This PRD externalizes and enhances SAP's system prompt in `config/agent_prompts/sap_system.md` to enforce atomic PRD/backlog outputs with guardrails. It mandates the use of ERB templates for structural skeletons and integrates vision from `MCP.md`. It also introduces a self-correction loop (max 2 attempts) to ensure output quality.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All prompt loads, modifications, and validation retries must be logged in `agent_logs/sap.log`.

#### Requirements
**Functional Requirements:**
- **Prompt Externalization**: Load prompt from `sap_system.md`; include dynamic inserts (e.g., vision from `MCP.md`, current backlog from `backlog.json`).
- **ERB Skeleton Enforcement**: 
    - Use `templates/prd.md.erb` for PRDs.
    - Use `templates/backlog_row.json.erb` for backlog updates.
    - Use `templates/epic.md.erb` for Epic overviews.
- **Validation & Self-Correction**:
    - Ruby validates AI output against mandated sections and AC counts (5-8 bullets).
    - If validation fails, Ruby re-runs the AI with a "fix-it" prompt (e.g., "Retry 1: Missing AC sections").
    - Max 2 retry attempts before falling back to an error log.
- **Guardrails**: Include challenges (e.g., "Challenge ideas if suboptimal"), privacy mandates (local-only), and Rails MVC standards in the system prompt.
- **Backlog Sync**: AI reads `backlog.json` and outputs updated entries via `backlog_row.json.erb`; Ruby validates and writes the update.

**Non-Functional Requirements:**
- Performance: Prompt load <50ms; prompt size <3K tokens.
- Security: Sanitize all dynamic inserts (JSON/vision) to prevent prompt injection.
- Privacy: All prompt processing and data ingestion is local.

#### Architectural Context
Integrate into `SapAgent::ArtifactCommand`. Use the Strategy pattern to select the correct ERB template and validation logic. Reference `config/agent_prompts/` for the system prompt.

#### Acceptance Criteria
- Prompt loads from `sap_system.md` and correctly integrates vision from `MCP.md`.
- `ArtifactCommand` uses ERB templates to provide structural skeletons to the AI.
- Self-correction logic correctly identifies missing AC bullets and triggers a retry.
- Retry limit (2) is enforced and logged.
- Backlog updates are processed via the AI-generated JSON and Ruby-enforced `increment_id`.

#### Test Cases
- Unit (RSpec): `ArtifactCommand` retry loop logic (mock failure, then success); template injection verification.
- Integration: VCR for AI call; assert that the final output matches the ERB structure.
- System: Submit malformed request -> verify logged retry attempts and final structured output.

#### Workflow
Junie: Use Claude Sonnet 4.5. Pull from master, branch `feature/0020-prompt-externalization`. Ask questions about "fix-it" prompt wording. Implement in atomic commits. PR to main.

