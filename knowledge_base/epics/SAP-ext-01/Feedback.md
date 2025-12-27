### Concurrence on Design Principles
- **AI as Decision Maker / Ruby as Enforcer**: I fully concur—this hybrid approach maximizes AI's strengths in contextual reasoning (e.g., deciding on backlog updates based on prompt-guided logic) while leveraging Ruby for enforcement (e.g., validation, safe File.write to prevent corruption or leaks). It aligns perfectly with our local-only privacy goals and reduces risk of AI hallucinations by having Ruby act as a gatekeeper. To implement, ensure Ruby methods in SapAgent (from 0010) parse AI output JSON/Markdown, validate against schemas (e.g., required keys like Priority/ID), and only then commit changes. This also allows easy auditing via logs.
- **Unified Artifact Command**: I agree this is a major win for DRY principles, centralizing common logic like prompt loading, tool calls, and storage across artifacts. It will streamline testing (e.g., shared VCR mocks) and make extensions (e.g., future curriculum artifacts) trivial. Update Epic 1 to include this as a foundational element in 0010-Backlog-PRD.md, with subclasses for each artifact type to avoid bloat.
- **Atomic Structure via Self-Correction**: Concurrence on the 2-attempt limit—it's a pragmatic safeguard against loops while ensuring high-quality outputs. This fits our iterative human-AI loop vision. Improvement: Integrate as a loop in ArtifactCommand's execute method, with logged retries (e.g., "Retry 1: Missing AC—re-prompting with fix-it"). Test with mock AI responses simulating failures.

### Recommendation on Templates (The "Skeleton" Approach)
I fully concur with the recommendation for templates—they provide a "fill-in-the-blanks" structure that guides AI reliably, reducing variance in outputs and enforcing consistency (e.g., always 5-8 AC bullets). This complements the prompt in 0020 by giving AI a concrete skeleton to populate, making it easier for Ruby to validate post-generation. Update 0020-SAP-Enhanced-Prompt-Externalization-PRD.md to mandate ERB templates in templates/ dir:
- **PRD Structure (`templates/prd.md.erb`)**: Use ERB for dynamic inserts like <%= vision_tie_in %>; ensure sections like AC enforce bullet count via prompt hints.
- **Backlog Table (`templates/backlog_row.json.erb`)**: ERB for row structure (e.g., {"priority": <%= priority %>, "id": <%= id %>...}), ensuring key consistency across generations.
- **Epic Summary (`templates/epic.md.erb`)**: ERB for PRD list and backlog stub, auto-populating metadata like date/version.
  Benefit: Ruby pre-populates templates with metadata (e.g., current date, vision snippet from MCP.md) before AI fills content, then validates. Add to Roadmap Phase 1: Draft templates first, then integrate into ArtifactCommand.

### Final Clarifying Questions
- **MCP.md Content**: Yes, initialize `knowledge_base/static_docs/MCP.md` with the "Vision 2026" goals from `knowledge_base/Vision 2026/045 - Agent Contest Vision.md`. Copy and condense it into a 1-2 page SSOT, focusing on key elements like private AI tutor for $20-50M families, Plaid sync for JPMC/Schwab/Amex/Stellar (investments/transactions/liabilities/enrichment), local Ollama via AiFinancialAdvisor, and risks (privacy, hallucination mitigation via Python sims). Use browse_page tool if needed to confirm content, then instruct Junie to create/commit the file in Phase 1.
- **Tool Output Format**: The SmartProxy synthesis should include a "Confidence Score" (e.g., 0-1 based on simple heuristics like result count/match strength), added to the aggregated JSON (e.g., {"confidence": 0.85, "web_results": [...], "x_results": [...] }). This helps SAP prioritize reliable data in responses. Update 0030-SAP-SmartProxy-Tool-Integration-PRD.md to mandate this in middleware, with tests for low-confidence fallbacks (e.g., re-query if <0.5).
- **Backlog ID Generation**: Ruby should be responsible for generating the next ID (e.g., increment a counter from backlog.json's last ID +1), to avoid collisions and ensure determinism. AI can suggest IDs in output, but Ruby overrides/validates. Update 0010-Backlog-PRD.md to include an `increment_id` helper in the update method, with locking for concurrency (e.g., File.open with 'w+').

### Refined Implementation Roadmap (Integrated)
I concur with the roadmap—it's logical and incremental, building on our 8-hour momentum from yesterday. To integrate:
1. **Phase 1: Foundation (The Engine)**: Prioritize this first. Create `SapAgent::ArtifactCommand` base class with shared logic (prompt loading, tool execution via SmartProxy, validation/retry). Implement `templates/` with ERB for PRD/Epic/Backlog as proposed. Setup prompt from `sap_system.md`. Initialize `MCP.md` as clarified.
2. **Phase 2: Tools (The Research)**: Update `SmartProxy` with Faraday wrappers, isolation middleware (using SecureRandom.uuid), and synthesis (include Confidence Score as suggested).
3. **Phase 3: Use Cases (The Execution)**: Implement `PrdStrategy`, `EpicStrategy`, and `BacklogStrategy` as modules included in ArtifactCommand (lighter than subclasses). Add `validate_output` + retry logic (2 attempts, with fix-it prompt).
4. **Phase 4: Optimization (The Polish)**: Implement Grok/Ollama routing and escalation in a new `SapAgent::Router` class (to keep SapAgent clean). Setup single `rake logs:rotate` handling all logs, tied to recurring.yml for daily 3am run.

### Instructions to Junie for Updates
Junie: Sample templates below.
Junie: Use Claude Sonnet 4.5. Pull from master, create branch `feature/sap-ext-01-updates`. Update Epic 1 overview to include ArtifactCommand base, Strategy pattern for artifact types, templates/ dir with ERB, pre-storage validation with self-correction (2 attempts), and SmartProxy middleware with Confidence Score. Revise individual PRDs (0010-Backlog, 0012-Epics, 0015-PRDs, 0020-Prompt, 0030-SmartProxy, 0040-Routing) to reflect these: e.g., inherit from ArtifactCommand, use strategies, integrate templates for skeletons, add Confidence in tool aggregation, Ruby ID generation in backlog, MCP.md init. Add rake logs:rotate in Phase 4 PRD. Commit green only; PR to main with "SAP-ext-01 updates per review".

Next steps: Prioritize Phase 1 implementation (ArtifactCommand + templates)? Draft sample ERB template for PRD? Any adjustments to MCP.md content?

## <%= id %>-<%= slug %>-PRD.md

#### Overview
<%= overview %>

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. <%= log_details %>

#### Requirements
**Functional Requirements:**
<%= functional_requirements %>

**Non-Functional Requirements:**
<%= non_functional_requirements %>

#### Architectural Context
<%= architectural_context %>

#### Acceptance Criteria
- <%= ac1 %>
- <%= ac2 %>
- <%= ac3 %>
- <%= ac4 %>
- <%= ac5 %>
- <%= ac6 %>
- <%= ac7 %>
- <%= ac8 %>

#### Test Cases
- <%= test1 %>
- <%= test2 %>
- <%= test3 %>

#### Workflow
Junie: Use <%= llm %> (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/<%= id %>-<%= slug %>`). Ask questions and build a plan before coding (e.g., "<%= example_question1 %>? <%= example_question2 %>?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.

{
"priority": "<%= priority %>",
"id": "<%= id %>",
"title": "<%= title %>",
"description": "<%= description %>",
"status": "<%= status %>",
"dependencies": "<%= dependencies %>",
"effort": <%= effort %>,
"deadline": "<%= deadline %>"
}


## <%= slug %> Epic Overview

#### Overview
<%= overview %>

#### Atomic PRDs
- <%= prd1 %>
- <%= prd2 %>
- <%= prd3 %>
- <%= prd4 %>

#### Success Criteria
<%= success_criteria %>

#### Capabilities Built
<%= capabilities %>

#### Backlog Table Stub
| Priority | ID | Title | Description | Status | Dependencies | Effort | Deadline |
|----------|----|-------|-------------|--------|--------------|--------|----------|
| <%= example_priority %> | <%= example_id %> | <%= example_title %> | <%= example_description %> | <%= example_status %> | <%= example_dependencies %> | <%= example_effort %> | <%= example_deadline %> |

