## 0040-SAP-Queue-Based-Storage-Handshake-PRD.md

#### Overview
This PRD replaces the legacy filesystem-only handshake with a robust Solid Queue-based mechanism for storing and transferring SAP artifacts. Instead of Junie directly reading files written by SAP, SAP enqueues a "storage job" that commits artifacts to Git and notifies Junie via a handshake job. This prevents race conditions, handles dirty states via stashing, and ensures the `backlog.json` and `TODO.md` are always in sync.

#### Acceptance Criteria
- Implement `SapAgent::StorageJob` to handle the asynchronous writing of PRDs to `knowledge_base/epics/`.
- Add Git operations to `StorageJob`: `git stash`, `git checkout main`, `git add`, `git commit -m "SAP: [ID] [Slug]"`.
- Replace direct filesystem writes in `SapAgent::PrdStrategy` and `SapAgent::EpicStrategy` with `perform_later` calls.
- Implement an "Outbox" pattern: store the artifact in a `pending_storage` table before attempting Git operations.
- Automatically update `backlog.json` status to "Stored/In Review" once the handshake is successful.
- Trigger a notification to the Rake CLI (from PRD 0030) upon successful storage.
- Ensure resilience: If Git commit fails (e.g., merge conflict), the job should retry with exponential backoff.

#### Architectural Context
- **Job**: `app/jobs/sap_agent/storage_job.rb`.
- **Database**: Add `pending_artifacts` table for the Outbox pattern.
- **Git**: Interface with system calls via `Open3` for robust error handling.
- **Sync**: Calls `SapAgent.sync_backlog` after successful storage.

#### Test Cases
- **TC1: Async Storage**: Verify that generating a PRD doesn't block the agent but instead enqueues a `StorageJob`.
- **TC2: Git Commit**: Confirm that the job correctly commits the file to the repository with the specified message format.
- **TC3: Dirty State Stashing**: Verify that if there are uncommitted local changes, the job stashes them before Git ops and restores them after.
- **TC4: Status Update**: Ensure `backlog.json` reflects the new status after the job completes.
- **TC5: Retry Logic**: Simulate a Git lock error and verify the job retries.
