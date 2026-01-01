# Agent-05 (Epic 5) — Review Feedback, Questions, Objections, Alternatives

Date: 2026-01-01

This document reviews:
- `knowledge_base/epics/AGENT-05/AGENT-05-Epic.md`
- `knowledge_base/epics/AGENT-05/AGENT-05-0050A.md`
- `knowledge_base/epics/AGENT-05/AGENT-05-0050B.md`
- `knowledge_base/epics/AGENT-05/AGENT-05-0050C.md`
- `knowledge_base/epics/AGENT-05/AGENT-05-0050D.md`
- `knowledge_base/epics/AGENT-05/AGENT-05-0050E.md`

## Executive summary (high-signal)

Epic 5’s direction is strong: **console-first multi-agent workflow with explicit ownership (“Ball with”) + guardrails** is the right foundation before any UI.

Main risks to address early:
1. **Gem fit & API uncertainty**: `chatwoot/ai-agents` capabilities and extension points (provider adapters, handoff semantics, tool calling, callbacks) must be confirmed before PRD-level commitments.
2. **Persistence/observability**: “context hash persists across handoffs” needs a storage story (in-memory only? file? DB?). Without this, debugging and UI tracking will be brittle.
3. **Safety boundary**: the “CWA can run shell/git/rake” portion is high-risk and needs a tight execution sandbox + explicit allowlist + audit trail.
4. **Test realism**: VCR for local SmartProxy/Ollama may be unstable unless the proxy responses are deterministic enough to record/replay.

Recommendation: treat `0050A` as a **spike + minimal runner** and explicitly validate the gem APIs and SmartProxy integration; then harden guardrails/logging before adding tool execution.

## Cross-cutting questions (please confirm)

### About `chatwoot/ai-agents`
1. What is the **exact gem name** and require path? (`ai-agents` vs `ai_agents` vs `ai_agents` module naming) There’s a high probability of naming mismatch.
2. Does the gem support:
   - Custom provider adapters (for SmartProxy → Ollama) without forking?
   - Multi-agent “handoff” with explicit `route_to` semantics?
   - Tool calling with structured arguments, and per-tool allowlists?
   - Callback hooks (`after_handoff`, logging hooks) suitable for Rails + thread safety?
3. Is there an existing example repo for Rails integration?

### About SmartProxy/Ollama integration
4. What is the canonical SmartProxy endpoint and request format?
   - Is it OpenAI-compatible (`/v1/chat/completions`) or custom?
   - Does it support streaming? (Even if console-first, streaming determines UI feasibility.)
5. Which model(s) should be default?
   - `llama3.1:70b` is heavy. Should PRDs assume `llama3.1:8b` for dev and allow override?
6. Do we have stable “test proxy” semantics (like ports `3002` for test) similar to Epic 4.5 patterns?

### About “Ball with”
7. Do you want “Ball with” to be:
   - purely derived from current agent name?
   - explicitly set by an agent decision (e.g., Coordinator says “ball_with=CWA”)?
   - a human override?
8. What are the “terminal” states?
   - `resolved`, `blocked`, `escalated_to_human`, `awaiting_feedback`, etc.

### Persistence / ownership tracking
9. Where should workflow state live between turns?
   - `agent_logs/` JSON artifacts?
   - Rails cache/Redis?
   - A DB table (PRDs say no migrations, but UI + resumability strongly benefit from DB.)
10. Are multiple concurrent runs required? If yes, we need a run identifier + storage keyed by that ID.

## Epic-level comments / objections

### Comment: “Strip gem to core” is good, but define the cut line
Right now “strip gem to core” is an intent, not a deliverable. Suggest adding a small definition:
- **Core** = runner + agent registry + handoff + context passing + tool calling (optional)
- **Not core** = any UI/webhook/chatwoot integration, multi-tenant chat inbox features, background jobs, etc.

### Objection: “No new models/migrations” may conflict with UI + audit needs
If you want `/admin/ai_workflow` to show live ownership/context/logs reliably, a DB model (even a tiny `AiWorkflowRun`) will pay off.

Alternative: keep “no migrations” for `0050A–C`, but revisit for `0050D`:
- `0050D` can optionally introduce a model if needed, or use `agent_logs/` as a first pass.

### Comment: The “Deprecation path for Junie via CWA integration” needs boundaries
If CWA can “commit” changes, that’s effectively autonomous coding. We should define:
- allowed directories, commands, and git operations
- whether it can push branches
- human review requirement
- traceability/audit record per action

## PRD 0050A feedback — Persona Setup & Console Handoffs

### Questions
1. What is the source of `vision.md` in this repo? (Path? There are multiple `knowledge_base/Vision 2026` documents.)
2. How strict is “parse MD to hash `{name: desc}`”?
   - Does `vision.md` have a consistent delimiter per persona?
   - Should we prefer YAML front matter or a dedicated `personas.yml` extracted from `vision.md`?
3. What is the success definition for “handoff to Coordinator if complex”?
   - rule-based heuristic?
   - LLM self-classification?
   - explicit user command (e.g., “assign to Coordinator”)?

### Objections / risks
4. `UUID.generate` is not Ruby standard. In Rails it’s typically `SecureRandom.uuid`.
5. “Support 5k token contexts without lag” is ambiguous:
   - 5k tokens in prompt only? prompt+completion?
   - depends heavily on model size and SmartProxy latency.
6. “Admin-only rake” is unclear:
   - Rake tasks are not user-facing; gating requires explicit environment checks or credentials.
   - If run on a server, who counts as “admin”? OS user? Rails user?

### Alternatives / simplifications
7. Start with a minimal CLI runner (no gem) as a baseline:
   - `AiWorkflowService.run(prompt:, correlation_id:)` uses existing `SapAgent` directly
   - Add “handoff” as pure Ruby orchestration
   - THEN swap in the gem runner if it adds real value

8. Persona source alternative:
   - Create `knowledge_base/personas.yml` generated from `vision.md` once
   - Keep `vision.md` as narrative source; stop parsing Markdown at runtime

9. SmartProxy adapter alternative:
   - If SmartProxy is OpenAI-compatible, use an existing OpenAI client adapter rather than custom HTTP.
   - If not compatible, define and lock down a small client module first (request/response schema) before tying it to the gem.

### Suggested acceptance criteria adjustments
10. Add a deterministic “handoff rule” acceptance test:
   - Input prompt contains string `[handoff:Coordinator]` → system routes to Coordinator
   - This avoids relying on “complexity” heuristics for the first milestone

## PRD 0050B feedback — Feedback & Resolution Loop

### Questions
1. What is the difference between:
   - “feedback loop” and “resolution routing”
   - “broadcast” and “cc: dev-group”
   Are these separate delivery mechanisms or just logging semantics?
2. What does “escalate stalls to human (24h)” mean in console-first scope?
   - print a banner + exit?
   - write a file in `agent_logs/`?

### Objections / risks
3. `request_timeout=30s` is likely too low for large local models (especially `70b`).
4. “Redis pubsub if bundle add redis” adds ops overhead. If we’re local-only, file-based may be enough for a long time.

### Alternatives
5. Define a single “transport” abstraction early:
   - `AiWorkflow::Transports::FileLog`
   - later add `RedisPubSub` behind the same interface
6. Use an explicit finite-state machine (FSM) in the context:
   - `state: awaiting_triage | awaiting_feedback | resolving | done | escalated`
   - This prevents “implicit state” hidden in free-form text.

### Suggested acceptance criteria adjustments
7. Add explicit “max turns” behavior:
   - When `turns_count >= max_turns`, set `state=escalated`, set `ball_with=Human`, and emit a single clear console summary.

## PRD 0050C feedback — Impl/Test/Commit with CWA

### Questions
1. Where should tool execution run?
   - inside the Rails process?
   - a separate sandbox process (recommended)?
2. What constitutes “tests green”?
   - `rake test` only?
   - also `rubocop`? `brakeman`?
3. Can CWA create and push branches, or only commit locally?
4. How should credentials be handled (git remote auth)?

### Strong objection: tool calling needs a hard sandbox boundary
Even with an allowlist, executing shell commands from an LLM inside the app is dangerous.

Safer alternatives:
5. **Out-of-process executor**:
   - Spawn a locked-down subprocess in `tmp/agent_sandbox/` with a minimal environment
   - Restrict working directory
   - Enforce per-command timeouts
   - Capture stdout/stderr to `agent_logs/`
6. **Two-man rule** for git:
   - allow `git diff` + `git status` from tools
   - require a human to approve before `git commit` and before any `git push`
7. Start with “dry-run tools”:
   - Tools return the commands they would run, without running them
   - Human reviews, then re-run with execution enabled

### Suggested acceptance criteria adjustments
8. Add explicit constraints:
   - Disallow any command outside the repo root
   - Disallow network egress (other than SmartProxy)
   - Disallow environment variable access/secrets printing

## PRD 0050D feedback — UI Layer & Tracking

### Questions
1. What is the expected “live update” mechanism?
   - Turbo Streams from server pushes?
   - polling from `agent_logs/`?
   - ActionCable is not desired per Epic 4.5 notes.
2. Where does UI read state from?
   - file (`agent_logs/`)
   - Rails cache/Redis
   - DB

### Objections / risks
3. “UI loads <1s” is hard if it reads large context hash / log files.
4. “Click to resolve (POST to handoff)” needs CSRF/auth and must not allow arbitrary agent switching.

### Alternatives
5. Start with a read-only UI:
   - show latest run + ownership + logs
   - no “resolve” button until guardrails and audit are in place
6. Use the same “console output artifacts”:
   - Runner writes a JSON summary file per run
   - UI reads the summary, not the full raw logs

## PRD 0050E feedback — Planning Phase for CWA

### Questions
1. Why is Planner after UI in the dependency chain? (It currently depends on `#4`.)
   - Planning seems more useful before implementation tooling, and can be console-first.
2. What is the micro-task schema?
   - simple strings are fine, but adding fields helps: `{id, title, files, commands, risk, estimate}`

### Alternatives
3. Move planning earlier:
   - `0050E` could be `#3` (after feedback loop, before CWA tool execution)
4. Avoid a tool subclass for the first pass:
   - Planning can be a pure prompt template producing JSON
   - Only add a formal tool when multiple agents reuse it

## Suggested re-sequencing (optional)

If you want the safest “value early” path:
1. `0050A`: spike runner + persona/context + deterministic handoff trigger
2. `0050B`: feedback loop + guardrails + storage/logging format
3. `0050E`: planner output JSON micro-tasks (console)
4. `0050C`: tool calling (dry-run first, then execute with sandbox)
5. `0050D`: UI read-only, then interactive controls later

## Concrete deliverable suggestions (to reduce ambiguity)

1. Define a canonical `context` schema early (even as a markdown block in PRD):
   - `correlation_id`
   - `ball_with`
   - `state`
   - `turns_count`
   - `feedback_history[]`
   - `artifacts[]` (paths/urls)
   - `micro_tasks[]`
2. Define a canonical “run artifact” on disk:
   - `agent_logs/ai_workflow/<correlation_id>/run.json`
   - `agent_logs/ai_workflow/<correlation_id>/events.ndjson`
This gives you audit + UI + debugging without DB migrations.
