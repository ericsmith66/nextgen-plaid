### PRD 0041D — SAP Oversight UI Pause/Resume Controls & Error Handling

**Goal**: Add pause/resume controls and resilient error handling to `/admin/sap-collaborate`, persisting run state (resume_token, phase/status) so runs can be halted/resumed and failures are surfaced with clear English banners.

#### Scope
- Wire UI buttons to pause/resume Adaptive Iterate (using `resume_token`) and add a thin wrapper for Conductor pause/resume if needed.
- Persist run state (status, phase, resume_token, correlation_id/idempotency_uuid, model_used) so restarts do not lose context (via SapRun fields).
- Surface failures/timeouts/aborts with user-friendly banners that include correlation_id.

#### Out of Scope
- Real-time transport (already in 0041C; reuse broadcasts/polling for updates).
- Full audit history and artifact links (0041E), beyond logging state changes needed for pause/resume.

#### Requirements
1) **Pause/Resume Controls**
   - UI buttons to Pause and Resume an active run.
   - Adaptive Iterate: call `SapAgent.iterate_prompt` with `pause: true` to capture `resume_token`; store it in SapRun.
   - Conductor: add minimal wrapper/flag to mark paused and allow resume; if not natively supported, provide a stub that stops new sub-agent dispatch and resumes from stored state (`conductor_resume` uses SapRun.state + resume_token to restart next phase).

2) **State Persistence**
   - Persist status, phase, resume_token, correlation_id, idempotency_uuid, model_used, last output snippet, and error_message in a DB-backed record (SapRun or interim table). This persistence will be reused/extended in 0041E for audit history.
   - Ensure resume survives server restarts (read SapRun to restore state).

3) **Error/Abort Handling**
   - Banner for failures/timeouts/token_budget_exceeded with English text and correlation_id; include error_message from SapRun.
   - Broadcast/poll responses include the error reason and status (failed/aborted) so UI updates immediately.
   - Add migration field: `error_message:text` to SapRun for recording abort reasons.

4) **UX Safeguards**
   - Disable Pause when already paused/complete; disable Resume when running/complete.
   - Friendly messages when attempting invalid actions (e.g., resume with no token).
   - Buttons use DaisyUI disabled styles (`btn-disabled`) based on SapRun.status.

#### Success Criteria / DoD
- Active run can be paused and later resumed; Adaptive iterate uses resume_token; Conductor has a functional pause/resume mechanism (wrapper if necessary).
- Run state (status/phase/resume_token/correlation_id/idempotency_uuid/model_used/error_message) is persisted and survives app restart.
- Error/abort reasons appear as English banners with correlation_id; UI buttons reflect current state and disabled states obey SapRun.status.
- No PII in stored/resumed data; outputs redacted where applicable.

#### Manual Test Plan
1) Pause/Resume Adaptive: Start Adaptive run → click Pause → see status “Paused” and banner with resume token stored; reload server → click Resume → run continues.
2) Pause/Resume Conductor: Start Conductor → pause mid-run → resume → phases continue in order (wrapper uses SapRun state/resume_token).
3) Invalid resume: Attempt Resume without active run or token → friendly error shown; no crash.
4) Error banner: Trigger token_budget_exceeded or forced error → banner with correlation_id and SapRun.error_message; state persisted as aborted/failed.
5) Buttons disable: While paused/complete, Pause button disabled; while running/complete, Resume button disabled (DaisyUI disabled style visible).

#### Deliverables
- Pause/resume UI controls and controller endpoints.
- Persisted run state (SapRun or equivalent) storing status/phase/resume_token/correlation_id/idempotency_uuid/model_used/output snippet.
- English error banners for failure/abort scenarios; buttons disabled appropriately by state.