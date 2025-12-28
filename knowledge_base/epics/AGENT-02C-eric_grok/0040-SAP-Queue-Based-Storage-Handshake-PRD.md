### 0040-SAP-Queue-Based-Storage-Handshake-PRD.md

#### Overview
This PRD replaces 0130 filesystem with Solid Queue jobs for SAP artifact storage and Junnie handshakes, including Git commits and backlog ties. Ties to vision: Ensures reliable data flow for future CWA autonomy, supporting internship deliverables like tax simulations.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All queue jobs, storage, Git ops, and errors must be logged in `agent_logs/sap.log` with structured entries (e.g., timestamp, artifact ID, commit status, outcome). Rotate logs daily via existing rake.

#### Requirements
**Functional Requirements:**
- **Queue Jobs**: Add SapStorageJob for storing artifacts (e.g., PRD MD to knowledge_base/epics/[ID]/); SapHandshakeJob for outbox enqueuing (notify via rake poll).
- **Git Ops**: After storage, system("git add/commit") with dirty state check/stash/pop; message includes ID/version.
- **Backlog Ties**: Auto-update backlog.json statuses on storage (call Epic 2 #update_backlog).
- **Error Handling**: Rollback on failure (delete partial files, git reset); concurrent safe with unique IDs.

**Non-Functional Requirements:**
- Performance: Job <200ms; commit async.
- Security: Sandbox writes to knowledge_base/.
- Compatibility: Rails 7+; use Solid Queue/system calls.
- Privacy: Anonymize in logs.

#### Architectural Context
Integrate with Epic 1 SapAgent (enqueue post-response); use Solid Queue from AGENT-01. Rails job for logic; no migrations. Tie to Epic 2 webhook for post-storage refresh. Test with mock system (stub git). Challenge: Dirty state resilience (stash always, pop on success).

#### Acceptance Criteria
- SapStorageJob stores MD file and commits with message.
- SapHandshakeJob enqueues notification for poll.
- Backlog updated on storage (status change).
- Dirty state stashes/pops; failure rolls back.
- Concurrent jobs no overwrites (timestamp IDs).

#### Test Cases
- Unit (RSpec): For jobs—stub system, assert File.exist? and git called; test backlog call.
- Integration: Enqueue jobs, assert file/commit/backlog updated; Capybara-like: Feature spec with javascript: true to visit /admin/handshake_status, click 'Trigger Storage', expect page.to have_content('Artifact stored'), expect page.to have_content('Backlog updated'), expect page.to have_content('Commit successful'), cover dirty state (mock dirty, expect page.to have_content('Stashed and popped')), failure (expect page.to have_content('Rollback complete')), concurrent (mock parallel, expect page.to have_content('Unique IDs assigned')).
- Edge: Concurrent (mock parallel, unique IDs); no backlog (skip update).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0040-sap-queue-based-storage-handshake`). Ask questions and build a plan before coding (e.g., "Job classes? Git message format? Rollback logic? Concurrent ID generation?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.
