# Epic 5: Reimagined Workflow (Agent-05)

### Epic Goal
Structure PRD generation/implementation as a persona-driven cycle with handoffs, feedback, resolution, and ownership tracking—console-first, then UI. Leverage `chatwoot/ai-agents` gem for multi-agent handoffs/tool calling/shared context/guardrails (wrap file/mail system, configure for Ollama via SmartProxy, register personas as agents with tools like safe shell/git/rake).

### Scope
- Personas in `vision.md` as registered agents.
- Console/rake for requests/generation/assign/resolve via gem runner.
- “Ball with” tracking in context metadata.
- `vision.md` injection as shared hash.
- UI for visual tracking.
- Strip gem to core (runner + agent registry + handoff + context passing; tool calling only when needed).
- Add custom guardrails (`safe_exec` allowlist, timeouts, `max_turns=5`).

### Workflow Context (Shared Schema)
All agents/tools operate on a shared `context` hash with a stable schema:
- `correlation_id` (String; `SecureRandom.uuid`)
- `state` (String; one of: `awaiting_feedback`, `in_progress`, `blocked`, `resolved`, `escalated_to_human`)
- `ball_with` (String; current owner persona/agent; human override allowed)
- `turns_count` (Integer)
- `feedback_history` (Array)
- `artifacts` (Array of paths/identifiers)
- `micro_tasks` (Array; populated by Planner)

### Run Artifacts (Observability)
Each run writes artifacts keyed by `correlation_id`:
- `agent_logs/ai_workflow/<correlation_id>/run.json` (latest summary/context)
- `agent_logs/ai_workflow/<correlation_id>/events.ndjson` (append-only event log)

Persistence may use a minimal DB model (`AiWorkflowRun`) if required for resumability/UI; otherwise file-based artifacts are the default.

### Non-Goals
- New `SapAgent` logic.
- Automated merges (manual review).
- Full chatbot web cruft (use only thread-safe runner).

### Dependencies
- `SapAgent` for generation.
- Git for branches.
- MiniTest/VCR for self-test.
- `bundle add ai-agents` (from `chatwoot/ai-agents`; `require 'agents'`).

### Risks/Mitigations
- Gem overkill → test simple handoff first (0050A).
- Stalls → gem timeouts/escalate (24h).
- Drift → PRDs as truth + context serialization.
- Non-deterministic LLM/network tests → use deterministic `WebMock` stubs for SmartProxy in test; defer live recordings until stable.
- Tool execution risk → out-of-process sandbox + dry-run-first; “AI commits locally, human pushes/merges”.

### End-of-Epic Capabilities
- Console request → SAP PRD draft with personas/context via gem handoffs.
- Assign/feedback/resolution loops with ownership (“Ball with: X”) in metadata.
- Micro-task breakdown for CWA as tool calls.
- UI banners/tabs for workflow visibility.
- Deprecation path for Junie via CWA integration.

### Atomic PRDs Table
| Priority | Feature | Status | Dependencies |
|----------|---------|--------|--------------|
| 1 | 0050A: Spike — Persona Setup & Console Handoffs (gem validation + minimal runner; multi-provider proof) | Todo | None |
| 2 | 0050B: Feedback & Resolution Loop (FSM states, guardrails/timeouts, file transport) | Todo | #1 |
| 3 | 0050E: Planning Phase for CWA (micro-task JSON contract) | Todo | #2 |
| 4 | 0050C: Impl/Test/Commit with CWA (sandboxed tools; AI local commits, human push/merge) | Todo | #3 |
| 5 | 0050D: UI Layer & Tracking (read-only v1; optional realtime later) | Todo | #4 |
