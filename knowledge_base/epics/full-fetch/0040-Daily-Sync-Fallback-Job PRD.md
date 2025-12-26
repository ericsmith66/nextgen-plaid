### PRD: 0040-Daily-Sync-Fallback-Job-PRD

#### Overview
Implement a daily fallback sync job using Solid Queue recurring jobs to check PlaidItem.last_webhook_at and trigger 90-day transaction incrementals or full holdings/liabilities refreshes if no webhook received in the last 24 hours, ensuring data freshness without relying solely on webhooks for curriculum reliability.

#### Log Requirements
Junie read <project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md

#### Requirements
**Functional:**
- Add migration for PlaidItem.last_webhook_at (datetime, nullable) if not present from previous PRDs.
- Create app/jobs/daily_plaid_sync_job.rb: Loop over PlaidItems; if last_webhook_at < 24.hours.ago or nil, enqueue product-specific syncs (e.g., PlaidTransactionSyncService for transactions with 90-day cursor, full /holdings/get and /liabilities/get for others).
- Schedule via Solid Queue recurring: Add `config/recurring.yml` entry for daily run at 2:00 AM (e.g., `daily_plaid_sync_job: { class: "DailyPlaidSyncJob", schedule: "at 2am every day" }`).
- Handle errors: Retry failed syncs (3x); log skips if ITEM_LOGIN_REQUIRED (enqueue re-auth flow).

**Non-Functional:**
- Performance: Process 10 Items <30s; throttle API calls (e.g., sleep 1s between).
- Security: Respect RLS in queries (e.g., PlaidItem.joins(:user).where(users: { family_id: current_family.id }) if multi-family); no unencrypted data.
- Rails Guidance: Use Solid Queue recurring (config/recurring.yml); rails g job daily_plaid_sync; test in dev.

#### Architectural Context
Aligns with Rails MVC: Job calls existing services (PlaidTransactionSyncService, holdings/liabilities equivalents); update PlaidItem model. Enhances daily FinancialSnapshotJob by ensuring fresh data for JSON blobs + static docs (0_AI_THINKING_CONTEXT.md, PRODUCT_REQUIREMENTS.md) in AI prompts via local Ollama. Supports all institutions; no schema breaks.

#### Acceptance Criteria
- Job schedules correctly: whenever -i shows daily entry; manual run (rake whenever:update_crontab) succeeds.
- Overdue check triggers sync: For PlaidItem with old last_webhook_at, enqueues correct jobs (check queue size).
- Fresh items skipped: If last_webhook_at recent, no enqueuing.
- Errors retried/logged: Simulated failure retries 3x; per junie-log-requirement.md.
- Multi-product: Handles transactions (90-day incremental), holdings/liabilities (full refresh).
- No rate overload: Throttling prevents >1 call/sec.

#### Test Cases
- Unit: spec/jobs/daily_plaid_sync_job_spec.rb – it "enqueues sync for overdue item" { create(:plaid_item, last_webhook_at: 2.days.ago); expect { job.perform }.to have_enqueued_job(SyncTransactionsJob) }.
- Integration: spec/services/plaid_sync_integration_spec.rb – it "updates data on daily run" { VCR.use_cassette('daily_sync') { job.perform; expect(Transaction.last.updated_at).to be > 1.minute.ago } }.

#### Workflow
Junie, pull from main, create branch `feature/full-fetch-0040-daily-sync-fallback-job`. Ask questions and build a plan before execution. Use Claude Sonnet 4.5 in RubyMine. Commit only green code (run bin/rails test, RuboCop). Push for review. Confirm with Eric before proceeding to next PRD.

Next steps: After merge, ready for 0050-Force-Full-Update-Feature-PRD? Any Junie questions to append?

#### Testing Instructions

**1. Automated Unit Tests**
Run the dedicated test suite for the fallback job to verify logic for fresh vs. stale items:
```bash
bin/rails test test/jobs/daily_plaid_sync_job_test.rb
```

**2. Manual Verification (Rails Console)**
You can simulate the job's behavior or trigger it manually in development:
```ruby
# 1. Enter console
bin/rails c

# 2. Check which items are currently "stale" (no webhook in > 24h)
PlaidItem.where("last_webhook_at < ? OR last_webhook_at IS NULL", 24.hours.ago).count

# 3. Run the job immediately to see enqueuing logic
DailyPlaidSyncJob.perform_now
```

**3. Scheduling Verification**
Verify that the job is registered in the recurring task configuration:
- Open `config/recurring.yml`
- Ensure the `daily_plaid_sync_fallback` entry exists with `class: DailyPlaidSyncJob` and a valid schedule (e.g., `at 2am every day`).

**4. Logs & Monitoring**
- Check `log/development.log` after running the job.
- Look for: `DailyPlaidSyncJob: Triggering fallback sync for Item ID: [X] (Last webhook: [Date])`
- Verify that `SyncHoldingsJob`, `SyncTransactionsJob`, and `SyncLiabilitiesJob` are enqueued in the logs.