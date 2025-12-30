### PRD 0041E — SAP Oversight UI Audit Trail & Artifacts

**Goal**: Persist and display audit history and artifacts for SAP Agent runs on `/admin/sap-collaborate`, with redacted user identifiers and English-first summaries.

#### Scope
- Add a DB-backed `SapRun` (or equivalent) model/table to store run lifecycle: status, phase, model_used, correlation_id, idempotency_uuid, user reference (redacted), output_json (redacted), artifact_path, resume_token, started_at/completed_at, and error_message.
- Render an audit table on the UI showing recent runs/actions with correlation_id and redacted user labels.
- Provide artifact display/download links when available; default to inline English summaries otherwise.

#### Out of Scope
- Creating new business logic for SapAgent; reuse existing outputs/artifacts.
- Real-time transport and pause/resume mechanics (already covered in 0041C/0041D); this PRD consumes the persisted data for audit.

#### Requirements
1) **Persistence**
   - Migration for SapRun (or equivalent) with fields: user_id (nullable), task, status enum (pending/running/paused/complete/failed/aborted), phase, model_used, correlation_id, idempotency_uuid, output_json (jsonb), artifact_path, resume_token, error_message, started_at, completed_at, timestamps.
   - Add indexes on `correlation_id` and `started_at`; validate uniqueness of `correlation_id` (or correlation_id/idempotency pair) to simplify lookups.
   - Status updates on start/pause/resume/complete/abort should write to SapRun.
   - Redact PII before saving output_json/error_message (use existing Redactor helper) and generate redacted user label like `User-#{Digest::SHA256.hexdigest(user.id.to_s)[0..7]}`.

2) **Audit UI**
   - Table lists recent runs: timestamp, redacted user label, task summary, status/phase, model_used, correlation_id/idempotency_uuid, and result (success/failed/aborted).
   - Provide pagination (e.g., Kaminari) or minimal filters; default ordering `SapRun.recent.order(started_at: :desc)`.

3) **Artifacts**
   - If an artifact_path exists, show a download/open link; otherwise display a short English summary of output_json.
   - Ensure links are safe (e.g., constrained to known directories) and handle missing files gracefully with an English message.
   - For downloads, use `send_file(artifact_path, disposition: 'attachment')` when file exists; if JSONB, allow inline RAG summary.

4) **Exposure & Safety**
   - Owner/admin only; no PII (use hashed/short user identifier). No raw emails in the table.
   - Correlation_id surfaced per row for troubleshooting.

#### Success Criteria / DoD
- SapRun (or equivalent) migration exists and records lifecycle events for runs.
- UI audit table renders recent runs with redacted user labels and correlation_ids; owner/admin only.
- Artifacts are linked/displayed when present; missing artifacts show a friendly message.
- Outputs and errors shown in English-first summaries; raw JSON hidden behind a toggle.
- No unhandled exceptions when listing or loading artifacts.

#### Manual Test Plan
1) Lifecycle logging: Start Adaptive run → verify SapRun row created (status running); complete → status complete with model_used and correlation_id (unique/validated).
2) Pause/Resume: Pause run → SapRun updated to paused with resume_token; resume → back to running/complete.
3) Failure path: Trigger token_budget_exceeded → SapRun status aborted/failed; audit row shows English reason and correlation_id.
4) Artifact link: Run that produces artifact_path → UI shows link; clicking opens/downloads; if file missing, friendly error shown.
5) Redaction/auth: Audit table shows hashed user label; non-admin cannot access.
6) Pagination: With >20 runs, audit view paginates (e.g., Kaminari) and keeps correlation_id/user labels redacted.

#### Deliverables
- Migration + model for SapRun (or equivalent) with required fields, indexes, and validation on correlation_id.
- Controller/view updates to list audit rows with pagination and redaction (`User-<hash>` labels).
- Artifact link handling and English-first summaries with optional raw JSON toggle; safe download handling.