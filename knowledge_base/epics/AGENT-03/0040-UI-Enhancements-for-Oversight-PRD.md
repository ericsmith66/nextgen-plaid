## 0040-UI-Enhancements-for-Oversight-PRD.md

#### Overview
This PRD extends AGENT-02C's human UI with real-time oversight features, including ActionCable updates, approval workflows, and audit logging for iteration monitoring. Ties to vision: Improves human-AI collaboration for Plaid dev oversight, ensuring accuracy in nextgen-plaid.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. Log all UI interactions, approvals, audits, ActionCable events, and errors in `agent_logs/sap.log` using the canonical schema extended with `sub_agent`, `queue_job_id`, `iteration`, and `pruned_tokens` when relevant. Include `timestamp`, `task_id`, `branch?`, `uuid`, `correlation_id`, `model_used`, `elapsed_ms`, `score?`, `user`, `action`, outcome. Sampling: if >100 entries/run, log every 5th after the first 20. Redact task content and PII in UI/audit logs (hash user_ids/emails). Rotate logs daily via existing rake; correlation_id flows through ActionCable payloads.

#### Requirements
**Functional Requirements:**
- **UI Extensions**: Add to /admin/sap-collaborate (from AGENT-02C-0030): ActionCable for real-time phase updates; approval forms per iteration (pause/resume buttons); audit log viewer (tables for actions). Scope ActionCable channels per tenant/family_id (broadcast_to current_user/family scope) to prevent leakage.
- **Auth/Roles**: Devise RLS for owner/admin (current_user checks) plus audit table (JSONB) backing UI viewer; redact sensitive content (store summaries only).
- **Alerts**: Surface failures/timeouts as DaisyUI banners with reason (e.g., timeout via TimeoutWrapper). Track live update latency and approval response time metrics via code_execution and display in dashboard.
- **Error Handling**: Log UI errors with correlation_id; fallback to read-only on auth fail; hash any PII in logs.

**Non-Functional Requirements:**
- Performance: Updates <100ms via ActionCable; per-step timeouts/backoff via TimeoutWrapper (150ms/300ms retries for broadcasts if needed).
- Security: Encrypt sessions; audit all approvals; enforce RLS scoping in channels/views; correlation_id for traceability.
- Compatibility: Rails 7+; Tailwind/DaisyUI/ViewComponent—no new gems beyond ActionCable if missing.
- Privacy: Anonymize user data in logs/UI; redact task content in audits; hash PII.

#### Architectural Context
Build on AGENT-02C-0030 controller/views; add ActionCable channels for broadcasts. No migrations; use Devise/Postgres RLS. Challenge: Concurrency (focus on simple pub/sub); test with Capybara for flows.

#### Acceptance Criteria
- UI shows real-time updates via ActionCable (e.g., phase complete) scoped to tenant/family_id with correlation_id in payload.
- Approval forms pause/resume iterations and record audit entries (JSONB) with redacted content.
- Audit logs display in tables using hashed user identifiers; sap.log includes extended schema fields.
- Devise RLS restricts to owners/admins; unauthorized users see read-only/fallback.
- Alerts show for failures/timeouts with DaisyUI banner and reason from TimeoutWrapper; latency/approval metrics visible.

- Unit (RSpec): For controller/channel—stub ActionCable broadcast, assert update sent with tenant scoping and correlation_id; test approval form post (state change + audit JSONB insert with redaction); audit query mock (assert table data uses hashed user ids); verify metrics capture latency values.
- Integration (Capybara): Feature spec with javascript: true; 
  - Step 1: User visits '/admin/sap-collaborate', starts iteration, and verifies the page auto-updates with 'Phase 1 complete' via ActionCable, matching AC for real-time updates.
  - Step 2: User clicks 'Pause Approval', fills in form, clicks 'Approve Resume', and verifies the page shows 'Iteration resumed', matching AC for approval forms.
  - Step 3: User navigates to audit section, verifies the page shows table with 'User: owner (hashed), Action: approve, Timestamp: now', matching AC for audit logs.
  - Step 4: User logs in as non-owner, attempts access, verifies the page shows 'Access denied (RLS enforced, read-only fallback)', matching AC for auth/roles.
  - Step 5: User mocks failure, verifies the page shows DaisyUI banner 'Alert: Timeout detected (correlation_id ...)', matching AC for alerts.
- Edge: No updates (idle channel); failed approval (log error); concurrent users (RLS isolate); contract test for ActionCable payload shape and metric presence.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0040-ui-enhancements-for-oversight`). Ask questions and build a plan before coding (e.g., "ActionCable channels? Approval form logic? Audit table? RLS checks? Alert banners?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.