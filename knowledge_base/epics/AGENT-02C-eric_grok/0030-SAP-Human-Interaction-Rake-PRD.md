### 0030-SAP-Human-Interaction-Rake-PRD.md

#### Overview
This PRD creates a rake task for human inputs to SAP, including query submission, summary prints, and feedback templates via pbcopy, with Devise auth for owner-only access. Ties to vision: Facilitates human-in-the-loop for PRD reviews, ensuring accurate stewardship education.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All rake runs, inputs, and notifications must be logged in `agent_logs/sap.log` with structured entries (e.g., timestamp, query, feedback, outcome). Rotate logs daily via existing rake.

#### Requirements
**Functional Requirements:**
- **Rake Task**: Add lib/tasks/sap.rake with sap:query[prompt] to submit natural language, print SAP summary/response, copy feedback template to pbcopy (e.g., "Feedback: [structured log]").
- **Poll/Notification**: Extend to sap:poll for queue outputs (print notifications, copy templates); tie to Mission Control dashboard for visibility (optional link).
- **Auth Integration**: Require Devise current_user (owner-only); run via console or protected route if UI.
- **Error Handling**: On invalid prompt, log and prompt re-entry; non-Mac pbcopy fallback to print.

**Non-Functional Requirements:**
- Performance: Run <100ms.
- Security: Auth check; sanitize templates.
- Compatibility: Rails 7+; use system("pbcopy").
- Privacy: No data leak in copies.

#### Architectural Context
Integrate with Epic 1 SapAgent for query routing; use Rails rake for CLI, Devise for auth. Tie to Epic 2 queue for poll. Test with mock system calls. Challenge: Cross-platform pbcopy (fallback to STDOUT); align to dashboard for future UI.

#### Acceptance Criteria
- rake sap:query submits prompt, prints summary, copies template.
- rake sap:poll prints queue outputs/notifications.
- Auth enforces owner-only (unauth errors).
- Non-Mac fallback prints instead of copy.
- Integration with queue shows notifications.

#### Test Cases
- Unit (RSpec): For rake—stub system, assert pbcopy called with template; test auth (mock current_user nil, assert error).
- Integration: Invoke rake, assert log and output; Capybara-like: Feature spec with javascript: true to visit /admin/sap_query, sign_in as owner, fill_in 'Prompt', click 'Submit', expect page.to have_content('Summary printed'), expect page.to have_content('Template copied'), sign_out, expect page.to have_content('Unauthorized'), cover non-Mac fallback (mock env, expect page.to have_content('Printed to console')), queue integration (expect page.to have_content('Notifications from poll')).
- Edge: Empty prompt (re-entry); queue empty (log no outputs).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0030-sap-human-interaction-rake`). Ask questions and build a plan before coding (e.g., "Template structure? Auth in rake? Fallback for pbcopy? Dashboard tie?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.
