### PRD 0041A — SAP Oversight UI Routing, Auth & Scaffold

**Goal**: Stand up the admin-only `/admin/sap-collaborate` page with English-first copy, basic form inputs, and guardrails. This is the foundation for later realtime/controls/audit work (0041B–0041E).

#### Scope
- Add route, controller shell, and view scaffold for `/admin/sap-collaborate` using Rails namespace routing (`namespace :admin do get 'sap_collaborate', to: 'sap_collaborate#index' end`).
  - Enforce owner/admin access with Devise + Pundit (`before_action :authenticate_user!`, `SapCollaboratePolicy` or `authorize_admin!`); block or redirect others without leaking data.
  - Render a simple form with task text, optional branch, optional correlation_id/idempotency_uuid (auto-generate defaults on render via `SecureRandom.uuid`).
  - Display a placeholder status/output area with English helper text (no live data yet).

#### Out of Scope
- Starting SapAgent flows (covered in 0041B).
  - Real-time updates, polling, or ActionCable (0041C).
  - Pause/resume controls or error banners (0041D).
  - Audit trail or SapRun persistence (0041E).

#### Requirements
1) **Routing & Auth**
   - `GET /admin/sap-collaborate` mounted under admin/owner constraint via namespace route. Non-admins see 403 or redirect with a friendly English message.
   - Use Pundit policy (e.g., `SapCollaboratePolicy`) with Devise authentication to enforce admin/owner.
   - Page shows generated correlation_id and idempotency_uuid by default (SecureRandom.uuid); allow user to overwrite before submit.

2) **Scaffold View**
   - English-first labels/placeholders; avoid JSON. Provide short helper text explaining each field.
   - Form fields: task (required), branch (optional), correlation_id (optional, defaulted), idempotency_uuid (optional, defaulted), flow selector (adaptive iterate vs conductor) disabled/placeholder until 0041B.
   - Use DaisyUI/Tailwind primitives (e.g., `form-control`, `input`, `label`, `btn`) for consistent admin styling.
   - Static status/output placeholders indicating upcoming features.

3) **UX & Safety**
   - Validation message for empty task (client-side or server-side), in plain English.
   - No data leakage for unauthorized users; no PII in view source.
   - Provide admin layout scaffold (`app/views/layouts/admin.html.erb`) with minimal nav and branding for this page.

#### Success Criteria / DoD
- Route resolves and renders for admin/owner; non-admin blocked/redirected.
- Form shows generated correlation_id/idempotency_uuid; task is required.
- English helper text present; no raw JSON shown; DaisyUI layout renders without console errors.
- No runtime errors in logs when visiting the page.

#### Manual Test Plan (happy/negative)
1) Admin visit: Log in as admin/owner → visit `/admin/sap-collaborate` → page renders with form and default IDs (correlation/idempotency auto-filled).
2) Required field: Submit with empty task (once wired) → see friendly validation message (“Task is required”).
3) Unauthorized: Log in as non-admin → visit page → see 403 or redirect with English message; no data rendered.
4) Layout: Page uses admin layout/nav; inputs styled with DaisyUI form controls.

#### Deliverables
- Route/controller/view scaffold committed with namespace route and Pundit policy stub.
- English copy for labels/help text.
- Defaults for correlation/idempotency generation (e.g., SecureRandom.uuid) in the view/controller.
- Admin layout scaffold with DaisyUI form styling.