## 0030-SAP-Human-Interaction-Rake-PRD.md

#### Overview
This PRD implements rake tasks for human interaction in SAP workflows, with auth, polling, and error surfacing for pausing/resuming iterations. Ties to vision: Provides oversight for AI-driven dev, ensuring human review in sensitive Plaid/curriculum tasks for accuracy in nextgen-plaid.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All rake invocations, polls, inputs, and errors must be logged in `agent_logs/sap.log` using the canonical JSON schema: { "timestamp": "ISO8601", "task_id": "string", "branch": "string (optional)", "uuid": "string", "correlation_id": "uuid", "model_used": "string", "elapsed_ms": integer, "score": float (optional) }. Rotate logs daily via existing rake (file-only for now).

#### Requirements
**Functional Requirements:**
- **Rake Task**: Add rake sap:interact[task_id] to lib/tasks/sap.rake; enforce owner-only via service object (SapAgent::AuthService.new(current_user).owner?) to avoid Devise coupling; mock Warden in tests.
- **Polling/Timeout**: Poll state every 10s (5min total timeout); output progress to stdout; pbcopy only when MacOS detected via RbConfig (fallback to temp file write and log path on other OS).
- **Input Handling**: Allow human to pause/resume, inject feedback via stdin; surface errors (e.g., queue failures) as DaisyUI/CLI alerts; sanitize inputs.
- **Error Surfacing**: Log and display timeouts/failures; fallback to manual review if polled state errors; emit correlation_id in outputs for traceability.

**Non-Functional Requirements:**
- Performance: Poll <50ms; low overhead; fixed retries (max 2) for polling failures; 5min timeout enforced centrally.
- Security: RLS for task access; sanitize inputs; DaisyUI toast/stdout alert for errors/timeouts when web-triggered.
- Compatibility: Rails 7+; no new gems—use existing Devise/AuthService.
- Privacy: Anonymize logs; no PII exposure; correlation_id for audits.

#### Architectural Context
Integrate with SapAgent states from AGENT-02C-0020; rake in lib/tasks. No models/migrations; use console for auth (Devise helpers). Challenge: CLI usability (focus on Mac pbcopy); test with mocks for determinism.

#### Acceptance Criteria
- Rake sap:interact[task_id] authenticates user and polls mock state.
- Outputs progress to stdout; pbcopy used only on MacOS, otherwise writes temp file and logs path.
- Handles input: Pauses/resumes with feedback injection; correlation_id surfaced in output.
- Times out at 5min, logs error.
- Surfaces queue failures as alerts in output (DaisyUI/stdout depending on trigger).
- Owner-only access (unauth rejects) via AuthService.

#### Test Cases
- Unit (RSpec): For rake task—mock AuthService owner/non-owner, assert reject for non-owner; stub polling (10s intervals, output assertions); test input handling (stdin mock, assert state update); cover timeout (force 5min, assert log/error); test pbcopy guard (RbConfig mock Mac vs non-Mac temp file path).
- Integration (Capybara): Feature spec with javascript: true; 
  - Step 1: User visits '/admin/sap-collaborate', clicks 'Start Rake Interact', fills in 'Task ID' with '123', clicks 'Poll', and verifies the page shows 'Polling state: Pending - Output copied to clipboard', matching AC for authentication and polling.
  - Step 2: User waits for mock 10s interval, verifies the page updates with 'Progress: Phase 2 complete', matching AC for progress output.
  - Step 3: User clicks 'Pause and Input', fills in 'Feedback' with 'Adjust logic', clicks 'Resume', and verifies the page shows 'Resumed with input logged', matching AC for input handling.
  - Step 4: User forces 5min mock, verifies the page shows 'Timeout: Error surfaced and logged', matching AC for timeout.
  - Step 5: User mocks queue failure, verifies the page shows 'Alert: Queue failure detected', matching AC for error surfacing.
  - Step 6: User logs in as non-owner, attempts interaction, verifies the page shows 'Access denied - Owner only', matching AC for owner-only access.
- Edge: No task_id (error); long poll (timeout); invalid input (sanitize/log); non-Mac pbcopy fallback writes temp file and logs path.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0030-sap-human-interaction-rake`). Ask questions and build a plan before coding (e.g., "Devise auth in rake? Polling mechanism? Output formats? Error alerts?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.