# Junie Log: PRD 0050 - Force Full Update Feature

Date: 2025-12-26
Epic: Full-Fetch
Status: Completed

## Context
Added a mechanism to manually trigger Plaid product refreshes via Rake tasks or UI buttons in Mission Control. This is particularly useful for forcing Plaid to backfill historical data (e.g., 730 days of transactions) or refreshing stale holdings.

## Changes

### Database
- Added `last_force_at` datetime column to `plaid_items` table to track and enforce the 24-hour rate limit.

### Background Jobs
- **ForcePlaidSyncJob**:
  - Implements the core logic for product-specific refreshes.
  - Calls `client.transactions_refresh` for the "transactions" product.
  - Calls `client.investments_refresh` for the "holdings" product.
  - Triggers a standard `SyncLiabilitiesJob` for "liabilities" (as Plaid doesn't have a specific refresh endpoint for this).
  - Enforces a 24-hour rate limit per item/product.
  - Enqueues follow-up standard sync jobs (`SyncTransactionsJob`, etc.) to process the results of the refresh.

### Controller & Routes
- **PlaidRefreshesController**:
  - `create` action: Validates user permissions (owner/admin only), checks rate limits, and enqueues the `ForcePlaidSyncJob`.
- **Routes**:
  - Added `POST /plaid_items/:id/refresh` as `plaid_item_refresh`.

### UI
- Updated `MissionControlComponent`:
  - Added a new "Force Refresh" section in the Plaid Items table actions.
  - Included buttons for `Txns`, `Holdings`, and `Liab`.
  - Buttons use standard Tailwind/DaisyUI primary styling.

### Rake Tasks
- Added `plaid:force_full_sync[item_id, product]` for manual backend execution.
- Added `plaid:backfill_history[item_id]` as a convenience shorthand for transaction backfills.

## Verification Results

### Automated Tests
- `test/jobs/force_plaid_sync_job_test.rb`: Verified job logic, API calls, and rate limit enforcement. (All Passed)
- `test/controllers/plaid_refreshes_controller_test.rb`: Verified authorization, route handling, and controller-level rate limit checks. (All Passed)

### Manual Check
- Verified that buttons appear in Mission Control dashboard.
- Verified that Rake tasks correctly initiate jobs.
- Verified that the database correctly records `last_force_at`.
