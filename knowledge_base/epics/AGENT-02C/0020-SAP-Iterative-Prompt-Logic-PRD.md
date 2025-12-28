## 0020-SAP-Iterative-Prompt-Logic-PRD.md

#### Overview
This PRD adds iterative prompt logic to SapAgent for decomposing tasks into phased multi-turn loops (max 5 iterations), with scoring for stop/escalation and human injection points. Ties to vision: Supports refined PRD/curriculum generation using accumulating context, improving AI reliability for wealth education in nextgen-plaid.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All iteration phases, scores, escalations, and human inputs must be logged in `agent_logs/sap.log` using the canonical JSON schema: { "timestamp": "ISO8601", "task_id": "string", "branch": "string (optional)", "uuid": "string", "correlation_id": "uuid", "model_used": "string", "elapsed_ms": integer, "score": float (optional) }. Rotate logs daily via existing rake (file-only for now).

#### Requirements
**Functional Requirements:**
- **Iterate Method**: Add #iterate_prompt to SapAgent (app/services/sap_agent.rb); input task (e.g., "Refine PRD"); decompose into 3-5 phases (outline, draft, refine) via Ollama self-prompt.
- **Loop Logic**: Run sequential LLM calls (default Ollama 70B); score output via Ollama eval (>80% confidence stop; <80% retry max 2); escalate to Grok 4.1 when score <70 or token budget >500; Claude Sonnet 4.5 if env toggle or Grok unavailable; hard max 5 iterations and 1000 tokens/run (abort/log on exceed). States: Pending/Paused/Resumed/Completed.
- **Human Injection**: Pause for input via rake (post-0030); append human feedback to context prefixed "Human feedback: ..."; accumulate prior outputs in context.
- **State Persistence**: Persist iteration state in lightweight store (JSON in memory for short runs; JSONB column via optional IterationState model/Postgres for longer/paused runs; include scores/context/correlation_id). Pause/resume signal stored in queue payload as JSON { "state": "paused", "resume_token": "uuid" }.
- **Error Handling**: On low score/escalation failure or budget exceed, log and fallback to single-shot.

**Non-Functional Requirements:**
- Performance: Iteration round <200ms; total <1s for 5 calls; hard 1000-token ceiling/run; TimeoutWrapper for per-step caps (e.g., prune 200ms) and fixed retries (max 2).
- Security: Sanitize human inputs; state encryption if queued; DaisyUI toast/stdout alerts for web-triggered errors/timeouts.
- Compatibility: Rails 7+; integrate with existing router—no new gems.
- Privacy & Models: Local Ollama priority; escalate per rules above; no external data in prompts.

#### Architectural Context
Extend SapAgent from AGENT-02A/B; use router for LLM calls/escalation (env toggle for Grok 4.1). No models/migrations; state as JSON in memory or Postgres if persisted. Challenge: Avoid infinite loops (hard caps); focus on PRD flows. Test with VCR for determinism, mock escalations.

#### Acceptance Criteria
- #iterate_prompt decomposes mock task into 3 phases and runs iterations.
- Scoring stops at >80% (mock eval); retries <80% (max 2) with fixed backoff.
- Escalates to Grok 4.1 on <70% or tokens >500; uses Claude Sonnet 4.5 when env toggle or Grok unavailable.
- Enforces hard max 5 iterations and 1000 tokens/run (abort/log if exceeded).
- Handles pause/resume with human input appended and resume_token honored from queue payload.
- Logs all phases/scores with canonical schema including correlation_id/uuid/model_used/elapsed_ms; errors fallback to single-shot without crash.
- Accumulates context across iterations (e.g., phase 2 includes phase 1 output) and persists state to JSONB when paused.

#### Test Cases
- Unit (RSpec): For #iterate_prompt—stub Ollama calls (mock phases, scores: 75% → retry, 85% → stop); assert final output aggregates; test escalation (score <70 or tokens >500 → Grok call; env toggle claude → Claude call); cover states (pause mock with resume_token, resume with input appended); enforce 5-iteration and 1000-token caps (abort/log).
- Integration (Capybara): Feature spec with javascript: true; 
  - Step 1: User visits '/admin/sap-collaborate', selects task 'Refine PRD', clicks 'Start Iteration', and verifies the page displays 'Phase 1: Outline complete - Score: 75%', matching AC for decomposition and iteration run.
  - Step 2: User sees low score trigger, verifies the page shows 'Retrying iteration 1' (max 2 retries), matching AC for scoring retry.
  - Step 3: User mocks score <70% or tokens >500, verifies the page shows 'Escalated to Grok 4.1 for phase 4' after env toggle, matching AC for escalation; if Grok unavailable and env toggle set to claude, verify Claude Sonnet 4.5 used.
  - Step 4: User clicks 'Pause', fills in 'Human Feedback' with 'Add more details', clicks 'Resume', and verifies the page shows 'Iteration 3: Refined with human input', matching AC for pause/resume handling.
  - Step 5: User mocks failure/budget exceed, verifies the page shows 'Fallback to single-shot logged, process aborted', matching AC for error fallback/budget cap.
  - Step 6: User checks accumulated context, verifies phase 2 output includes phase 1 content, matching AC for context accumulation.
- Edge: Max 5 iterations (force loop, assert cap); no human input (auto-complete); low scores throughout (escalate and stop); soak sim of 5 parallel loops (mocked) respects token/iteration caps without timeouts.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0020-sap-iterative-prompt-logic`). Ask questions and build a plan before coding (e.g., "Scoring prompt template? State persistence? Escalation env? Human input format?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.