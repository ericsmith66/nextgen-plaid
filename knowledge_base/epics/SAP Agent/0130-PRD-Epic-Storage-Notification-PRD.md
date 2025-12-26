### 0130-PRD-Epic-Storage-Notification-PRD

#### Overview
This PRD defines the storage and handshake mechanism between SAP and Junie. It replaces disparate logs with a unified `Inbox/Outbox` folder structure and provides a `Junie CLI` rake wrapper to streamline the "manual" handshake.

#### Inbox/Outbox Registry
Instead of disparate logs, SAP and Junie will use a shared registry:
- `knowledge_base/epics/sap-agent-epic/inbox/`: SAP writes JSON tasks here (e.g., `new_prd.json`) for Junie.
- `knowledge_base/epics/sap-agent-epic/outbox/`: Junie moves processed tasks here or writes responses.
- `knowledge_base/epics/sap-agent-epic/archive/`: Completed tasks are moved here.

#### Junie CLI Wrapper
Implement `rake junie:poll_inbox` to check for new tasks, print a summary, and copy relevant info to the clipboard (via `pbcopy`).

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All storage, registry movements, and notifications must be logged in `agent_logs/sap.log`.

#### Definition of Done (DoD)
- **Inbox/Outbox**: Registry folders created and used for all handshakes.
- **Rake Task**: `rake junie:poll_inbox` functional and uses `pbcopy`.
- **Git Hygiene**: SAP checks for dirty state and stashes before committing new PRDs.
- **Testing**: RSpec for `Inbox/Outbox` logic and Git interaction mocks.

#### Requirements
**Functional Requirements:**
- **Storage**: SAP parses Grok responses and saves them as Markdown files in epic-specific folders.
- **Registry**: Implement logic to write to `inbox/` and read from `outbox/`.
- **Handshake**: `rake junie:poll_inbox` outputs task summaries and copies implementation instructions to the clipboard.
- **Git Ops**: SAP uses system calls for `git add/commit`. Must include dirty state checks and `git stash` in the workflow.
- **Overview Update**: Auto-update `0000-Epic-Overview.md` with new entries and changelogs.
- **Notification**: Include embedded template instructions in the rake output for Junie to follow.
- **Error Handling**: Stash changes if Git dirty; rollback on failure; log all failures.

**Non-Functional Requirements:**
- Performance: <100ms for storage/commit; handle up to 1KB Markdown outputs; log rotation adds <50ms.
- Security: Sanitize filenames/content to prevent injection (e.g., slugify query for names); use read-write only on knowledge_base/ dir.
- Compatibility: Rails 7+; no new gems—use built-in File/Git system calls.
- Privacy: Ensure stored content has no unsanitized data; align with local-only execution.

#### Architectural Context
Integrate into SapAgent service post-routing (e.g., in a store_output method called after parse_response). No new models/migrations—use filesystem for storage (knowledge_base/epics/[slug]/ subdir; create if missing) and logs (epic/logs/; .gitignore to exclude from Git). Reference static docs for formatting (e.g., ensure PRD structure matches MCP template). Align with Git workflow: Assume repo is clean; use system("git ...") for commits/stash to keep simple; handle dirty states resiliently. Templates as plain text strings in rake output for simplicity—no separate files yet. Prepare for future queues (post-CWA): Design storage/review as enqueuable jobs via Solid Queue for async agent comms, replacing manual pastes. Test with mocked File/system calls; defer complex Git integrations (e.g., libgit2) unless needed.

#### Acceptance Criteria
- SAP processes a mock Grok response and stores valid Markdown file in epic folder with auto-name/version (e.g., sap-agent-epic/001-test-prd-v1.md).
- File content matches parsed response exactly (e.g., manual diff shows no changes).
- Git commit succeeds on storage (e.g., git log shows new entry with message including version).
- 0000-Epic-Overview.md updates with new PRD entry and changelog (e.g., list appends "001... -v1: Initial").
- Notification rake outputs clipboard-ready summary with embedded template instructions for Junie logging, validation append, and SAP review trigger.
- rake sap:review_changes triggers SAP routing, logs feedback, and revises PRD to -v2 if needed.
- Junie logging template enforced: Output instructs structured/daily-rotated log entries; manual verification shows format in example.
- Error resilience: Handles dirty Git by stashing, retries failures, and rolls back without corruption.
- Invalid response (e.g., empty content) skips storage, returns error hash, and logs warning.
- Concurrent calls don't overwrite files (e.g., unique naming via timestamp or increment).
- No unsanitized data in files (e.g., query with script tags is escaped/slugified).

#### Test Cases
- Unit: RSpec for store_output method—mock response parsing; test file write (assert File.exist?(path)); verify Git system calls/stash (stub `system`); check naming/versioning/slugify (assert_match(/^\d{3}-.+-\.md$/, filename)); test overview update (assert_match(/ -v1: /, File.read(overview_path))); verify log rotation (mock date, assert renamed file).
- Integration: Test full SAP flow with VCR Grok cassette; enqueue job, assert file created/committed/revised; simulate notification rake and assert output includes template; run review rake and assert query routed/revision stored; edge cases like large content, dirty repo, or failed commit.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0130-prd-epic-storage-notification`). Ask questions and build a plan before coding (e.g., "Log rotation logic? Template string structure? Handle Git stash/pop on success? Version detection method?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.

Next: Generate PRD-0140, or implement this with Junie?