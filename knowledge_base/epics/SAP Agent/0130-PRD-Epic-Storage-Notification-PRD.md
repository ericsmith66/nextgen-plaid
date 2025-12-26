### 0130-PRD-Epic-Storage-Notification-PRD

#### Overview
This PRD defines the output storage and notification mechanism for SAP-generated epics/PRDs, automatically saving them as Markdown files in epic-specific folders (e.g., knowledge_base/epics/sap-agent-epic/) and notifying Junie via rake output for manual dialog paste/review/implementation. It includes templates with instructions for Junie to log actions (in epic/logs/junie_actions.log) and trigger SAP reviews of changes/inputs (via rake sap:review_changes[path_to_output]), enabling bidirectional loops while automating manual copy-paste from Grok outputs to repo. This supports streamlined workflow for HNW financial data syncing by facilitating reliable handoff to Junie for atomic Plaid features.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards, ensuring all storage operations, file commits, notifications, Junie action logs, and SAP review triggers are logged with timestamps, file paths, and error traces in epic-specific logs/ subdir (e.g., knowledge_base/epics/sap-agent-epic/logs/sap.log and logs/junie_actions.log; rotate daily as junie_actions-YYYY-MM-DD.log; create dir/files if missing; append entries like "Timestamp | Action | Details | Status").

#### Requirements
**Functional Requirements:**
- Extend sap_agent.rb to parse Grok responses (e.g., extract generated Markdown content from JSON "choices[0].message.content") and store as atomic files in epic folders (e.g., knowledge_base/epics/sap-agent-epic/0100-SmartProxy-Sinatra-Server-PRD.md; auto-create folder if missing; use incrementing IDs based on epic sequence).
- Handle storage: Use File.write to save parsed content; support versioning (append -v1, -v2 on revisions, e.g., via query param or auto-detect); commit to Git (via system calls like `git add` and `git commit -m "Add/Revise PRD from SAP: [query summary] -v[version]"`) only if valid (e.g., non-empty, well-formed Markdown); push to main if ENV['AUTO_PUSH'] (default false); update 0000-Epic-Overview.md by appending new/ revised PRD entries to a list with changelogs (e.g., "0100... -v2: Added tool support").
- Notification for Junie: Trigger a rake task (e.g., rake junie:notify_new_prd[file_path]) that outputs a clipboard-ready summary (e.g., via `pbcopy` on Mac: "New PRD ready: [path] – paste this to Junie dialog for review") for manual copy-paste into RubyMine; include embedded template instructions in the output (e.g., "Junie: Log your actions in [epic/logs/junie_actions.log] [format: Timestamp | Action | Details | Status]. After changes, run rake sap:review_changes[path_to_your_output] to trigger SAP review of inputs/changes. Append 'Validation Steps' section to this PRD.md with 3-5 bullets on manual verification (e.g., 'Run rake and confirm output'). Commit updated PRD.").
- SAP Review Trigger: Add rake sap:review_changes[input_path] that invokes SAP to route a review query (e.g., "Review Junie's changes in [path] against PRD") via SmartProxy/Grok, parsing response for feedback, logging in epic/logs/sap_reviews.log, and optionally updating PRD with revisions (-vN).
- Junie Logging: In notification template, instruct Junie to log every action (e.g., "Reviewed PRD", "Implemented model", "Fixed bug") with details (e.g., branch, commit hash) in epic/logs/junie_actions-YYYY-MM-DD.log using structured format; rotate logs daily via simple File.rename if over size/date.
- Error handling: Wrap in try-catch; retry file writes/commits on conflicts (up to 2 times); stash changes if Git dirty (system("git stash push")); rollback on failure (e.g., git reset); return status hash (e.g., { "success": true, "path": "/path/to/prd.md" }); log all failures.

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