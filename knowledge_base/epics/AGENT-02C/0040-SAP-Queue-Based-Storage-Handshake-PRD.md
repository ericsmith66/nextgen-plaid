## 0040-SAP-Queue-Based-Storage-Handshake-PRD.md

#### Overview
This PRD adds queue-based storage handshake in SapAgent for committing iteration artifacts idempotently, with conflict handling. Ties to vision: Ensures reliable storage of reviewed code/PRDs, supporting autonomous workflows for Plaid data models in nextgen-plaid.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All queue operations, commits, conflicts, and errors must be logged in `agent_logs/sap.log` using the canonical JSON schema: { "timestamp": "ISO8601", "task_id": "string", "branch": "string (optional)", "uuid": "string", "correlation_id": "uuid", "model_used": "string", "elapsed_ms": integer, "score": float (optional) }, plus commit hash/idempotency UUID where applicable. Rotate logs daily via existing rake (file-only for now).

#### Requirements
**Functional Requirements:**
- **Handshake Method**: Add #queue_handshake to SapAgent (app/services/sap_agent.rb); input artifact (e.g., JSON review); commit to git with format "AGENT-02C-[ID]: [Task Summary] by SAP [Links to PRD: AGENT-02C-0040]"; author "SAP Agent <sap@nextgen-plaid.com>"; target branch main after feature merge.
- **Idempotency**: Use UUID keys to avoid duplicates; check existing commits via code_execution (git log parse); log idempotency UUID + commit hash in schema.
- **Conflict Handling**: Preflight git status must be clean; if dirty, stash/apply with max 3 retries; abort on merge conflicts, log error.
- **Storage**: Push to main after green tests; support DRY_RUN/no-push flag via ENV['DRY_RUN']; fallback manual if fails.

**Non-Functional Requirements:**
- Performance: Handshake <500ms; retry limit 3 for stash/apply; soak goal: handle 10 queued jobs without breaching TTL.
- Security: Green commits only; auth git pushes; DaisyUI/stdout alert for web-triggered errors/timeouts.
- Compatibility: Rails 7+; use system git—no new gems.
- Privacy: No PII in commits; anonymize artifacts; include correlation_id for audits.

#### Architectural Context
Integrate with SapAgent from AGENT-02C; use Solid Queue for async if extended. No models/migrations; code_execution for git ops. Challenge: Git conflicts (focus on clean workspaces); test with mocks.

#### Acceptance Criteria
- #queue_handshake commits mock artifact with correct format/uuid and author, appending "[Links to PRD: AGENT-02C-0040]" to commit message.
- Handles idempotency: Skips duplicate UUID and logs hash/uuid in canonical schema.
- Preflight enforces clean workspace; stashes/retries dirty state up to 3, then aborts/logs on conflicts.
- Respects DRY_RUN env (no push) and pushes only when tests are green.
- Logs all outcomes with correlation_id, commit hash, elapsed_ms; DaisyUI/stdout alert on failure for web-triggered runs.
- Supports fallback/manual when git unavailable, logging warning.

#### Test Cases
- Unit (RSpec): For #queue_handshake—stub code_execution (git status mock dirty, assert stash with max 3 retries; log parse for duplicate, assert skip); assert commit message/format/author/suffix; cover abort on conflict mock; DRY_RUN skips push; log includes uuid/hash/correlation_id.
- Integration (Capybara): Feature spec with javascript: true; 
  - Step 1: User visits '/admin/sap-collaborate', clicks 'Initiate Queue Handshake', and verifies the page shows 'Committed: AGENT-02C-0040: Task Summary by SAP', matching AC for commit.
  - Step 2: User runs again with same UUID, verifies the page shows 'Skipped: Duplicate detected', matching AC for idempotency.
  - Step 3: User mocks dirty workspace via git status stub, verifies the page shows 'Workspace stashed and retried successfully', matching AC for dirty handling.
  - Step 4: User mocks merge conflict, verifies the page shows 'Aborted: Conflict detected and logged', matching AC for conflict abort.
  - Step 5: User stubs failing tests, verifies no push and page shows 'Push aborted: Tests not green', matching AC for green push.
  - Step 6: User checks logs, verifies the page or console reflects all outcomes logged with correlation_id/uuid/hash, matching AC for logging.
- Edge: No artifact (error); failed tests (no push); uuid collision (skip); DRY_RUN true skips push with log; soak sim of 10 queued jobs respects retry limits and TTLs.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0040-sap-queue-based-storage-handshake`). Ask questions and build a plan before coding (e.g., "Git command mocks? Idempotency check? Conflict abort logic? Push auth?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.