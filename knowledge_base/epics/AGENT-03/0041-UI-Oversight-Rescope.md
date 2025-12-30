### PRD 0041 — SAP Oversight UI (Rescope)

**Goal**: Deliver a minimal, user-friendly (English-first) admin UI at `/admin/sap-collaborate` to oversee SAP Agent runs with real-time visibility, basic controls, persisted audit history, and redacted outputs. Prefer human-readable text over raw JSON wherever feasible.

#### Objectives
- Provide an owner/admin-gated page to start/monitor SAP Agent flows (adaptive iteration, conductor) and view status/output in plain English.
- Show real-time updates (ActionCable preferred; polling fallback acceptable) for phase changes and completions.
- Allow basic controls: start, pause/resume, and view/download artifacts/outputs.
- Display audit history with redacted user identifiers and timestamps.
- Surface errors/timeouts with clear banners and correlation IDs.
- Persist run state (start, pause/resume, complete/abort) so runs survive app restarts and feed the audit table.

#### Non-Goals
- No new SAP business logic—the UI orchestrates existing `SapAgent` service calls.
- No full artifact editor; read-only display/download is sufficient.
- No multi-tenant UX beyond owner/admin guard (keep simple RLS/authorization).

---
### Requirements

1) **Routing & Auth**
   - Add `GET /admin/sap-collaborate` (admin/owner only) using Devise + Pundit (e.g., `before_action :authenticate_user!` + `authorize_admin!` / `SapCollaboratePolicy`). Redirect/403 for others with friendly English copy.
   - Auto-generate correlation_id/idempotency_uuid when omitted; propagate in all responses/events and flash/success messages.

2) **Start & Control Flows**
   - Start Adaptive Iterate and Conductor flows with minimal inputs: task text, optional branch, optional correlation/idempotency IDs.
   - Pause/Resume control for ongoing runs (UI button triggers service call/hook). `iterate_prompt` already returns `resume_token`; add a thin wrapper/persistence to pause/resume Conductor if required.
   - Buttons/labels in English; avoid exposing raw JSON unless user requests details.

3) **Live Status & Logs**
   - Display current phase/status, model used, iterations completed, and elapsed time.
   - Real-time updates via ActionCable channel keyed by correlation_id; fallback to periodic polling if Cable unavailable (show a banner when falling back).
   - Show recent log events in human-readable form (translate key fields: phase, model, score, reason). Provide “view raw JSON” toggle. Emit structured JSON logs for each event (includes correlation_id, idempotency_uuid, status/phase, model_used) to ease parsing/grep.

4) **Outputs & Artifacts**
   - Present final output/summary in readable text (headings, paragraphs). Avoid dumping raw JSON by default.
   - If an artifact path is produced, show a download/open link; otherwise display inline text.
   - Use `SapAgent::RagProvider` to humanize/translate technical errors (e.g., token_budget_exceeded → “Run aborted: exceeded token limit”) and summarize raw outputs. Include sample RAG prompt snippets such as `"Humanize error: [json] → 'Run stopped due to token limit exceeded'"` to guide implementation.

5) **Audit Trail**
   - Table/list of recent actions (start, pause, resume, abort, complete) with timestamp, redacted user label, correlation_id/idempotency_uuid, and result.
   - Persist audit rows in a DB-backed model (e.g., `SapRun` with status enum, phase, model_used, output_json, artifact_path, resume_token) so state survives restarts and can be queried without log parsing.
   - No raw emails or PII; use hashed/short identifiers (e.g., `user_label: User-#{Digest::SHA256.hexdigest(user.id.to_s)[0..7]}`) and redact displayed outputs.

6) **Errors, Timeouts, Guardrails**
   - User-friendly banners for failures/timeout/token budget aborts; include correlation_id.
   - If ActionCable is down, show a warning and continue with polling.

7) **English-first UX**
   - Labels, statuses, and summaries in plain English; hide JSON unless requested (toggle/accordion).

---
### Success Criteria / DoD
- `/admin/sap-collaborate` renders for admin/owner; non-admin blocked.
- Can start Adaptive Iterate and Conductor runs from UI; status updates appear live or via fallback polling.
- Pause/Resume works (iterate_prompt resume_token, conductor wrapper if needed) and reflects state in UI and audit log.
- Outputs are readable (English text). Raw JSON is optional behind a toggle; RAG summaries humanize errors/results.
- Audit table shows recent actions with redacted user identifiers and correlation IDs; entries persist in DB (SapRun).
- Error/timeout cases surface clear banners with correlation IDs; Cable fallback banner shown when applicable.
- Logging continues to `agent_logs/sap.log` (or Rails log) with correlation_id and model_used; broadcasts/poll responses carry these IDs and are structured JSON for grep/analysis.

---
### Updated Manual Test Plan (0041)

**Prep**
- `RAILS_ENV=development`; `bundle install`; `yarn install` if needed.
- Ensure `agent_logs/sap.log` exists (`mkdir -p agent_logs && touch agent_logs/sap.log`).
- Start app (and ActionCable if separate): `bin/rails server` (+ `bin/rails action_cable:server` if required).
- Sign in as owner/admin.

**Happy paths**
1) Start Adaptive Iterate
   - Go to `/admin/sap-collaborate`, enter task “Generate PRD for webhook ingestion”, click Start.
   - Expect live updates (phase, model, iteration count) and final readable summary. `agent_logs/sap.log` shows `iterate.*` events; SapRun row created/updated.

2) Start Conductor
   - Enter task “Decompose PRD for payments”, click Orchestrate.
   - Expect ordered phases (Outliner → Refiner(s) → Reviewer) with readable status; final summary shown. Logs show `conductor.*`; SapRun status becomes complete.

3) Pause/Resume
   - While a run is active, click Pause; expect status “Paused” and audit entry (SapRun status=paused, resume_token stored). Click Resume; expect run continues and audit updates.

4) Artifact link (if produced)
   - If output includes an artifact path, expect a link/button to view/download; text shown in English summary.

**Negative/edge cases**
5) Unauthorized user
   - Log in as non-admin; expect redirect/403 and no data leaked.

6) ActionCable unavailable
   - Stop Cable or simulate failure; expect banner “Live updates unavailable; falling back to refresh” and polling still shows status. Correlation_id remains visible in UI/logs.

7) Token budget abort or failure
   - Trigger a large input or force an error; expect banner with reason and correlation_id; audit entry recorded; logs show abort; SapRun status moves to aborted/failed.

8) Guardrail on inputs
   - Submit empty task; expect validation error in English (no crash/no JSON dump).

9) Idempotency/correlation defaults
   - Omit correlation_id/idempotency_uuid; expect UI to auto-generate and surface them in status and audit rows.

---
### Implementation Tasks (high level)
1) Routes & Controller
   - Add `GET /admin/sap-collaborate` under admin/owner constraint.
   - Controller actions to render page, start runs (adaptive, conductor), pause/resume, and fetch status (for polling fallback). Auto-generate correlation/idempotency when blank.

2) View (DaisyUI/Tailwind if available)
   - Form to start runs (task text, optional branch, correlation/idempotency IDs).
   - Live status panel (phase, model, iterations, elapsed) and output panel (English summary, optional raw JSON toggle).
   - Controls for Pause/Resume; artifact link if present.
   - Audit table with redacted user IDs and correlation IDs.
   - Error/alert banners.

3) ActionCable (preferred) + Polling fallback
   - Channel broadcasting run status/log events keyed by correlation_id/task_id; broadcast on status/log changes and after pause/resume.
   - JS client subscribes; if subscription fails, use polling endpoint.

4) Service hooks
   - Wire controller actions to `SapAgent.iterate_prompt`, `SapAgent.conductor`, and pause/resume helpers (or add thin wrappers plus persistence for conductor pause/resume if needed).
   - Ensure responses include correlation_id/model_used for UI display; persist resume_token/state into SapRun.

5) Logging/Audit
   - Ensure controller logs structured events with correlation_id and redacted user.
   - Add SapRun model/migration (status enum: pending/running/paused/complete/failed/aborted; fields for phase, model_used, correlation_id, idempotency_uuid, output_json, artifact_path, resume_token, started_at/completed_at).
   - Persist audit entries (DB-backed) for start/pause/resume/complete/fail; redact outputs before display.

6) UX polish (English-first)
   - Human-readable labels/messages; hide JSON behind toggle.
   - Validation messages for empty/invalid inputs.

7) Tests / Manual Verification
   - Happy/negative paths above; verify admin gating, SapRun persistence, and Cable fallback.

---
### Suggested Atomic Breakdown
- **0041A: Routing, Auth & Scaffold** — Route/controller/view shell, admin guard, simple form.
- **0041B: Start Flows & English Summaries** — Wire iterate/conductor start, show readable status/output with RAG humanization.
- **0041C: Real-Time Updates** — ActionCable channel + polling fallback with correlation_id propagation.
- **0041D: Pause/Resume & Errors** — Persist resume_token/state in SapRun; pause/resume controls; banners for errors/aborts.
- **0041E: Audit & Artifacts** — SapRun model migration, audit table with redacted users, artifact links/downloads.
