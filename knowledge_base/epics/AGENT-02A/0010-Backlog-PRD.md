### 0010-Backlog-PRD.md

#### Overview
This PRD implements the `BacklogStrategy` for the unified `SapAgent::ArtifactCommand` engine. It enables SAP to manage a `backlog.json` registry with Ruby-enforced integrity (incremental ID generation, JSON schema validation) while leveraging AI for contextual pruning (YAGNI logic) and status detection. It ensures the project backlog aligns with the Vision 2026 priorities defined in `MCP.md`.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All backlog operations (generate, update, prune) must be logged in `agent_logs/sap.log`. Include details on ID generation and validation outcomes.

#### Requirements
**Functional Requirements:**
- **BacklogStrategy**: Implement as a module included in `ArtifactCommand`.
- **Incremental ID Generation**: Ruby method to calculate next ID (last ID + 1) from `backlog.json` to avoid collisions; AI suggestions are overridden by Ruby.
- **Backlog Management**: 
    - AI decision-making: Decide on additions/updates/pruning based on query and `MCP.md` vision.
    - Ruby enforcement: Parse AI output using `backlog_row.json.erb`, validate schema (Priority, ID, Title, Description, Status, Dependencies, Effort, Deadline), and use `File.write` with locking.
- **YAGNI Pruning**: AI identifies stale "Low" priority items (>30 days) for pruning; Ruby logs rationale and performs the deletion.
- **Git Integration**: Use `git log` regex on PRD IDs to auto-update statuses in `backlog.json`.

**Non-Functional Requirements:**
- Performance: Backlog load/parse <100ms.
- Security: Sanitize JSON inputs; file locking (e.g., `File.flock`) for concurrent writes.
- Privacy: All operations remain local.

#### Architectural Context
Inherit from `SapAgent::ArtifactCommand`. Use `knowledge_base/backlog.json` as the SSOT. Implement `increment_id` helper in Ruby. Integrate with `SapAgent::Router` for cost-effective execution (Ollama for simple updates).

#### Acceptance Criteria
- `ArtifactCommand` correctly instantiates `BacklogStrategy`.
- Ruby generates incremental IDs regardless of AI output.
- Schema validation rejects malformed AI JSON.
- `backlog.json` updates are atomic and use file locking.
- Stale items are pruned with rationale logged.
- Statuses update based on mock git log matches.

#### Test Cases
- Unit (RSpec): `increment_id` correctly handles empty vs. populated JSON; schema validation catches missing keys.
- Integration: Concurrent write test with `File.flock`; VCR for AI pruning decision.
- System: Submit "Add core setup to backlog" -> verify `backlog.json` has new entry with next ID and vision-aligned description.

#### Workflow
Junie: Use Claude Sonnet 4.5. Pull from master, branch `feature/0010-backlog-strategy`. Ask questions about exact JSON schema and prune thresholds. Implement in atomic commits. PR to main.