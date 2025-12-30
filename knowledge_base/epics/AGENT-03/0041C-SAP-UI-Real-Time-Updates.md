### PRD 0041C — SAP Oversight UI Real-Time Updates (ActionCable + Polling)

**Goal**: Provide live status/log updates for SAP Agent runs on `/admin/sap-collaborate` using ActionCable, with a reliable polling fallback. Propagate correlation_id on all broadcasts/responses.

#### Scope
- Add an ActionCable channel (e.g., SapRunChannel) keyed by correlation_id (and/or idempotency_uuid) to broadcast status/log events from start actions.
- Add polling endpoint for status/log retrieval when Cable is unavailable; UI shows a banner when falling back.
- Client-side subscription that updates the status/output panels in real time (Stimulus/ES6 controller with Cable + polling fallback).

#### Out of Scope
- Initiating runs (0041B) and pause/resume (0041D) behaviors—reuse existing start responses for broadcasts.
- Audit persistence and artifact display (0041E), aside from including current artifact_path in broadcast if present.

#### Requirements
1) **ActionCable Channel**
   - Channel subscribes with correlation_id; rejects missing/invalid params.
   - Broadcast events on status/log changes (start, phase updates, completion, abort) including: correlation_id, phase/status, model_used, iterations/score (if available), elapsed_ms (if available), artifact_path (if present), and a humanized message.
   - Include broadcast example in code/docs: `SapRunChannel.broadcast_to(correlation_id, { phase:, status:, model_used:, humanized: SapAgent::RagProvider.summarize(phase), artifact_path: })`.

2) **Polling Fallback**
   - Provide `GET` endpoint to fetch latest status/log for a given correlation_id (e.g., `def status; render json: SapRun.find_by(correlation_id: params[:id]).as_json; end`).
   - UI detects Cable failure (subscription error/timeout) and falls back to polling with a visible banner: “Live updates unavailable; falling back to refresh.”

3) **UI Updates**
   - Status panel updates in real time: phase, model_used, iterations count, elapsed.
   - Logs list shows recent events in English-first text with timestamps; raw JSON toggle allowed.
   - Correlation_id remains visible in the UI.
   - Stimulus (or equivalent) controller handles subscription and polling fallback (e.g., `connect: subscribe if Cable up; otherwise poll every 5s`).

4) **Resilience & Safety**
   - Handle missing correlation_id gracefully with an English error message.
   - No PII in broadcasts; redact outputs before sending.

#### Success Criteria / DoD
- ActionCable broadcasts status/log updates keyed by correlation_id; client receives and updates UI without page refresh.
- When Cable is disabled, UI shows fallback banner and continues updating via polling.
- Correlation_id is present on all payloads; no PII appears in channel messages.
- No unhandled exceptions in logs for channel or polling endpoints.

#### Manual Test Plan
1) Live updates: Start Adaptive run; observe phase/model updates in UI without refresh; correlation_id displayed; log entries appear.
2) Cable down: Stop ActionCable server; reload page; see fallback banner; polling continues to refresh status/logs.
3) Missing correlation: Attempt to open status view without correlation_id; see friendly error.
4) Raw toggle: View logs list → toggle raw JSON on/off; default hidden.
5) Stimulus fallback: Disable Cable client (simulate connection error) → Stimulus controller shows banner and switches to 5s polling; status still updates.

#### Deliverables
- ActionCable channel implementation with correlation_id subscription and broadcasts.
- Polling endpoint and client fallback logic with banner.
- UI wiring to update status/log panels in real time (or via polling) with English-first text and raw toggle.