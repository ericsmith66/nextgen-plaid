### PRD 0041B — SAP Oversight UI Start Flows & English Summaries

**Goal**: Enable the `/admin/sap-collaborate` page to start SAP Agent flows (adaptive iterate and conductor) with human-friendly inputs/outputs. Present results in English-first summaries, hiding raw JSON behind a toggle.

#### Scope
- Wire the scaffolded page (0041A) to `SapAgent.iterate_prompt` and `SapAgent.conductor` start actions.
- Auto-generate correlation_id/idempotency_uuid when blank and surface them in the UI (flash success includes correlation_id).
- Render status/output statically (no live updates yet) with English summaries (use RagProvider to humanize technical reasons like token_budget_exceeded).
- Provide a “view raw JSON” toggle for advanced users; default view is redacted/plain English.

#### Out of Scope
- ActionCable/polling real-time updates (0041C).
- Pause/resume controls (0041D).
- Audit persistence/artifact download table (0041E), except storing minimal response to display.

#### Requirements
1) **Start Actions**
   - Controller endpoints to start Adaptive Iterate and Conductor flows from the form (`start_iterate`, `start_conductor`).
   - Accept task (required), branch (optional), correlation_id/idempotency_uuid (optional, defaulted), and flow type selection.
   - Generate defaults with `SecureRandom.uuid` when blank; include correlation_id in flash success. Store response payload in memory/session for rendering.
   - Example controller stub: `def start_iterate; resp = SapAgent.iterate_prompt(params.permit(...)); session[:sap_response] = resp; flash[:notice] = "Started (#{resp[:correlation_id]})"; render :show; end`.

2) **English-first Output**
   - Use `SapAgent::RagProvider` (or similar helper) to produce short English summaries of results/errors. Include a helper example: `def humanize_response(json); SapAgent::RagProvider.summarize("Summarize in English: #{json.to_json}"); end`.
   - Show key fields: status/phase, model_used, iterations count (if returned), and any artifact path text.
   - Provide a “Show raw JSON” toggle; hide by default. Redact sensitive fields if present.

3) **Error Handling**
   - User-friendly messages for invalid inputs (e.g., missing task) and agent errors (e.g., token_budget_exceeded → “Run aborted: exceeded token limit”).
   - Correlation_id surfaced in the UI for troubleshooting.

#### Success Criteria / DoD
- Admin can start both Adaptive Iterate and Conductor from the page; receives a rendered status/output view.
- Correlation_id/idempotency_uuid shown (auto-generated when blank) and included in flash notice.
- Outputs are readable English; raw JSON is hidden behind a toggle.
- Errors are displayed in English with correlation_id; no stack traces exposed.

#### Manual Test Plan
1) Adaptive start: Enter task “Generate PRD for webhook ingestion” → Start Adaptive → see status/output with correlation_id in flash and page; raw JSON hidden until toggled.
2) Conductor start: Enter task “Decompose PRD for payments” → Start Conductor → see phase/model summary; raw JSON toggle works.
3) Missing task: Submit without task → friendly validation error.
4) Token budget abort: Provide large input to trigger abort → banner/text “Run aborted: exceeded token limit” with correlation_id.
5) Humanize helper: Force an error JSON and confirm English summary appears instead of raw JSON by default.

#### Deliverables
- Controller actions and view rendering for start flows with English summaries and flash correlation_id.
- Helper for RAG humanization of responses/errors with example usage.
- Toggle for raw JSON output, default hidden.
- Input validation and correlation/idempotency auto-generation.