### Review Summary of PRD 0041 — SAP Oversight UI (Rescope)

#### Strengths
- Well-aligned with implemented SAP agent: References existing methods like `SapAgent.iterate_prompt` (basic iteration with pause/resume via resume_token) and `SapAgent.conductor` (orchestrated phases: Outliner → Refiner(s) → Reviewer). Objectives match code's correlation_id, model_used, and logging to `agent_logs/sap.log`.
- Minimal scope: Orchestrates without new logic—good for Junie's Rails focus (MVC, generators). English-first UX leverages implemented RAG (RagProvider for human-readable summaries via Ollama).
- DoD/AC verifiable: Ties to code (e.g., start run → log events like "iterate.start", "conductor.complete"; pause → "iterate.paused" with resume_token).
- Test plan solid: Covers happy/negative paths, including ActionCable fallback—matches code's error handling (e.g., token_budget_exceeded abort).

#### Weaknesses
- Assumes pause/resume fully implemented: Code has pause in `iterate_prompt` (returns resume_token), but not in `conductor` or `adaptive_iterate`—add hooks (e.g., state persistence in SapRun model) to support.
- Audit persistence unclear: Code logs to file (`agent_logs/sap.log`), but PRD's table needs DB (e.g., SapRun for start/pause/complete with redacted user). Log-based is inefficient for UI (parsing required).
- No RAG tie-in: UI could use RagProvider for English summaries of outputs/logs (e.g., humanize "token_budget_exceeded" to "Run aborted: exceeded token limit").
- Idempotency/correlation: Inputs good, but code uses them inconsistently (e.g., conductor generates idempotency_uuid)—UI should auto-generate if blank.
- No adaptive_iterate: PRD mentions "Adaptive Iterate" but code has separate `adaptive_iterate` (with escalation, failure_streak)—clarify if UI starts basic or adaptive.

#### Critical Issues
- Missing SapRun model: For stateful runs (pause/resume across sessions, audit table). Code uses in-memory state—add DB persistence to avoid loss (e.g., on server restart).
- ActionCable setup: Code lacks channels—implement SapRunChannel (broadcast by correlation_id).
- Security/Redaction: Code has Redactor for anonymization—integrate into UI (e.g., redact outputs before display). Owner guard matches User#owner?.
- Backlog/Strategy: Implemented (BacklogStrategy, sync_backlog)—UI could include backlog view (ties to RagInspector from commit 2579779).
- No agent-2A/2B/2C/Agent0-3 explicit: Code's conductor uses sub-agents (run_sub_agent for :outliner/:refiner/:reviewer)—assume these map; if not, PRD needs sub-flow controls.

#### Recommendations
- break into a epic with multiple atomic PRDs
- Add SapRun model/migration: `rails g model SapRun user:references task:text status:enum phase:string model_used:string correlation_id:string idempotency_uuid:string output_json:jsonb artifact_path:string error_message:text started_at:datetime completed_at:datetime` (enum status: pending/running/paused/complete/failed/aborted). Use for audit table (SapRunsController index).
- Enhance service hooks: Add `SapAgent.start_adaptive_iterate` wrapper (calls adaptive_iterate with escalation). For pause/resume, persist SapRun on pause (store resume_token/state).
- UI: Use DaisyUI for panels/table (e.g., daisyui-card for status, daisyui-table for audit). Toggle raw JSON via Alpine.js.
- Tests: Add Capybara for UI (e.g., visit /admin/sap-collaborate, fill task, click Start → assert status updates). Mock Ollama responses with WebMock.
- LLM: Stick to Claude Sonnet 4.5 for Junie—reliable for Rails.
- Workflow: Junie: Pull main, branch `feature/prd-41-sap-ui`; plan: Review SapAgent code (app/services/sap_agent/*), add SapRun, then build UI. Questions: Confirm agent-2A/etc. mapping to conductor sub-agents.

Next steps: If ok, proceed; else, rescope PRD for SapRun first (new atomic PRD).

### breaking PRD 0041 into an epic with multiple atomic PRDs aligns better with guidelines—it's currently a mid-sized feature bundling routing/auth, UI components, real-time (Cable/polling), service hooks, and audit/logging. This risks implementation sprawl for Junie; atomic splits ensure reliable, testable steps.

### Suggested Epic Structure: "SAP Oversight UI"
- **Epic Goal**: Build admin UI for SAP Agent oversight, starting with core scaffolding and layering real-time/controls/audit.

Atomic PRDs (prioritized):
1. **PRD 0041A: SAP UI Routing, Auth & Basic Page** - Setup /admin/sap-collaborate with Devise/Pundit gating; render simple form for task inputs.
2. **PRD 0041B: Start Flows & Basic Status Display** - Integrate SapAgent calls (iterate_prompt/conductor); show static status/output in English (humanize via RAG).
3. **PRD 0041C: Real-Time Updates (ActionCable + Polling)** - Add broadcasting for phase/model/iterations; JS subscription with fallback.
4. **PRD 0041D: Pause/Resume Controls & Errors** - Implement buttons/hooks; add banners for failures/timeouts with correlation_ids.
5. **PRD 0041E: Audit Trail & Artifacts** - Add SapRun model/table; display redacted history; handle artifact links/downloads.

### Comments on Original PRD
- Strengths: Ties well to agents (e.g., iterate_prompt/conductor from agent-2A/2C); test plan covers implemented pause (resume_token).
- Weaknesses: Overlooks SapRun model (critical for state/audit); assumes full pause in conductor (add in 0041D); no RAG for English summaries (integrate in 0041B).
- Risks: Without splits, Junie might merge ungreen code—atomics enforce green commits per PRD.

Next steps: Confirm if SapRun exists (browse https://raw.githubusercontent.com/ericsmith66/nextgen-plaid/main/app/models/sap_run.rb: "Extract full code if present"). Want me to generate the first atomic PRD (0041A)?