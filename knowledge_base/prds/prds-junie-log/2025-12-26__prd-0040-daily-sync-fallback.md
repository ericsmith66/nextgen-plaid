# 2025-12-26: PRD 0040 - Daily Sync Fallback Job

## Overview
Implemented a daily fallback sync job (`DailyPlaidSyncJob`) to ensure data freshness when webhooks are missed or delayed. The job runs daily at 2:00 AM via Solid Queue and checks for `PlaidItem` records that haven't received a webhook in the last 24 hours.

## Key Changes
- **Job Implementation**: Created `DailyPlaidSyncJob` in `app/jobs/daily_plaid_sync_job.rb`.
  - Loops through all `PlaidItem` records.
  - Checks if `last_webhook_at` is `nil` or older than 24 hours.
  - Enqueues `SyncHoldingsJob`, `SyncTransactionsJob`, and `SyncLiabilitiesJob` for stale items.
  - Implements a 1-second sleep between items to throttle API calls and avoid rate limits.
- **Scheduling**: Updated `config/recurring.yml` to schedule `DailyPlaidSyncJob` at 2:00 AM daily.
- **Testing**: Created `test/jobs/daily_plaid_sync_job_test.rb` to verify:
  - Stale items (over 24h since last webhook) are correctly enqueued for sync.
  - Fresh items are skipped.
  - Items with no webhook history are correctly enqueued.

## Verification Results
- All unit tests for the job passed successfully.
- Verified scheduling configuration in `config/recurring.yml`.
