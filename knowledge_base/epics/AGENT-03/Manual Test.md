### Manual testing checklist for Epic AGENT-03

Below are end-to-end manual checks for each PRD (0010–0050), assuming the current work on branch `feature/agent-03` (or your active AGENT-03 branch), Rails app running locally, DB migrated, and `agent_logs/sap.log` writable.

#### Common prep
- Ensure clean working tree (`git status` clean) and up-to-date deps: `bundle install`, `yarn install` if needed.
- Set env defaults: `RAILS_ENV=development`, `ESCALATE_LLM` optional; ensure `agent_logs/sap.log` exists (`mkdir -p agent_logs && touch agent_logs/sap.log`).
- Start app + ActionCable (if using puma/cable): `bin/rails server` and `bin/rails action_cable:server` if separate.
- Admin user signed in (owner/admin) for `/admin/sap-collaborate`.

---
#### PRD 0010 — Adaptive Iteration Engine
**Goal:** Adaptive retries/escalation, token caps, logging.
1) **Happy path with retries then stop**
    - UI: Go to `/admin/sap-collaborate`, start “Adaptive Iteration” with task like “Generate PRD”.
    - Expected: Iteration 1 logged/visible; if score <80, see message “Retrying (1/2)”. After a higher score, flow stops with “completed”.
    - Log: `agent_logs/sap.log` entries `adaptive.iteration` / `adaptive.complete` with iteration number, elapsed_ms, model_used.
2) **Escalation on low score or high tokens**
    - Force low score/token >500 (via test hook or stub if available). Re-run.
    - Expected: Message “Escalated to Grok 4.1 (1/1 escalation used)” (or next model per config). Only one escalation max.
    - Log: `adaptive.escalate` once; no second escalation.
3) **Token budget abort**
    - Provide very large input to exceed 500 tokens.
    - Expected: Status “aborted — token_budget_exceeded”, partial output returned.
    - Log: `adaptive.abort` with reason `token_budget_exceeded`.
4) **Iteration cap**
    - Force consistently mid scores so it keeps retrying.
    - Expected: Stops at max iterations (7) with reason `iteration_cap`.

CLI alternative (bypassing UI):
```bash
bundle exec rails runner "puts SapAgent.adaptive_iterate(task: 'Test Adaptive').to_json"
```
Check log for iterations, escalation, abort reasons as above.

---
#### PRD 0020 — Multi-Agent Conductor
**Goal:** Outliner → Refiner(s) → Reviewer routing, max jobs, circuit breaker, logging.
1) **Normal routing order**
    - UI: `/admin/sap-collaborate` → “Orchestrate” task.
    - Expected: Messages in order: Outliner complete → Refiner iterations (3–5) → Reviewer scored final.
    - Log: `conductor.*` entries with `sub_agent` and `queue_job_id` in order.
2) **Max jobs guardrail**
    - Trigger with refiner iterations >5 (if configurable) or inject over-limit payload.
    - Expected: Abort with reason `max_jobs_exceeded`; no further routing.
3) **Circuit breaker fallback**
    - Simulate 3 consecutive sub-agent failures (stub errors or kill queue worker).
    - Expected: Message “Circuit-breaker tripped… falling back to in-memory”; flow continues in-process.
4) **Idempotency/correlation propagation**
    - Verify state JSON (if exposed) carries `idempotency_uuid` and `correlation_id`; log entries include them.

CLI alternative:
```bash
bundle exec rails runner "puts SapAgent.conductor(task: 'Decompose PRD', refiner_iterations: 3).to_json"
```
Check `agent_logs/sap.log` for order, circuit breaker, reasons.

---
#### PRD 0030 — Dynamic Context Pruning
**Goal:** Prune to <4k tokens, respect 2k min-keep, relevance/age weights, logging.
1) **No-op under target**
    - Call with small context (<4k tokens).
    - Expected: Returns unchanged; log `prune.skip` (if present) or no prune entries.
2) **Prune with heuristics**
    - Provide context >4k tokens with mixed “relevant” and “old” sections.
    - UI: `/admin/sap-collaborate` → “Prune”.
    - Expected: Output reduced to ~target but not below 2k; notes about retained high-score sections and age-based drops.
    - Log: `prune_context.complete` with `pruned_tokens` and retained/dropped reasons.
3) **Min-keep warning**
    - Use very large but mostly low-relevance content so min-keep blocks further pruning.
    - Expected: Warning “Could not prune below 2k floor”; returns near-floor content.
4) **Failure path**
    - Force an error (e.g., invalid JSON input) if possible.
    - Expected: Warning banner; returns full context; log `prune_context.error` with reason.

CLI alternative:
```bash
bundle exec rails runner "puts SapAgent.prune_context(context: '...very long text...').to_json"
```
Inspect log for `prune_context` events.

---
#### PRD 0040 — UI Enhancements for Oversight
*(UI may still be in progress; adjust based on what’s implemented.)*
1) **Real-time updates**
    - Open two browser windows as the same tenant/admin.
    - Start an iteration/conductor action on `/admin/sap-collaborate`.
    - Expected: ActionCable updates appear in the other window (e.g., “Phase 1 complete”) within ~100ms; payload includes correlation_id.
2) **Approval flow**
    - Click “Pause/Approve/Resume” controls for an iteration.
    - Expected: State changes reflected, audit entry recorded, UI shows resume confirmation.
3) **Audit log viewer**
    - Open audit section/table.
    - Expected: Rows with hashed/anonymized user identifiers, actions, timestamps; no raw emails.
4) **Auth/RLS**
    - Log in as non-owner/non-admin and visit the page.
    - Expected: Access denied or read-only fallback; no ActionCable data for other tenants.
5) **Alerts/metrics**
    - Simulate a failure/timeout (e.g., block ActionCable or trigger TimeoutWrapper).
    - Expected: DaisyUI banner with reason and correlation_id; latency/approval metrics visible.

---
#### PRD 0050 — Async Queue Processing
**Goal:** Batch enqueue with guardrails, TTL/dead-letter, encryption headers, UI monitoring, logging.
1) **Enqueue batch (<=10)**
    - UI: `/admin/sap-collaborate` → “Queue Batch”, choose 3–5 items.
    - Expected: Confirmation “Batch enqueued via Solid Queue (sap_general)”; log `queue_task.enqueue` with `queue_job_id`.
2) **Guardrail reject >10**
    - Attempt batch of 11.
    - Expected: Immediate error “Batch too large (max 10)”; no enqueue; log reason.
3) **TTL expiration**
    - Set TTL short in config or simulate clock; let job expire.
    - Expected: Job moved to `sap_dead`; UI shows “expired”; log `queue_task.dead_letter`.
4) **Encryption header**
    - Inspect stored/enqueued payload (logs or console) to confirm versioned header (v1/v2) present; payload anonymized.
5) **Failure + retry fallback**
    - Stop Solid Queue worker and enqueue.
    - Expected: One in-memory retry attempted; on failure, log with `queue_job_id` and notify UI.
6) **UI monitoring**
    - Watch dashboard for status transitions (pending → processing → completed/dead-letter) with redacted payload summary.

CLI alternative (if helper exposed):
```bash
bundle exec rails runner "puts SapAgent.queue_task(batch: [{id: 'task1'}], correlation_id: SecureRandom.uuid).to_json"
```
Check `agent_logs/sap.log` for `queue_task` events, TTL/dead-letter handling.

---
#### Logs & validation (all PRDs)
- Verify `agent_logs/sap.log` entries follow schema: `timestamp, task_id, branch, uuid, correlation_id, model_used, elapsed_ms, score?` plus `sub_agent/queue_job_id/iteration/pruned_tokens` when relevant.
- Ensure no PII in logs (hashed user IDs/emails), and DRY_RUN or env flags respected where applicable.

If you want these condensed into a runnable script (like the AGENT-02C handshake script) for AGENT-03 flows, I can draft targeted runners for adaptive_iterate, conductor, prune_context, and queue_task with log greps.