### PRD: 0020-Transactions-Sync-Service-PRD

#### Overview
Implement a new PlaidTransactionSyncService using Plaid's /transactions/sync endpoint for cursor-based incremental transaction pulls (default 90 days ongoing, full 730 days initial), replacing /transactions/get to avoid duplicates and optimize API usage. This enables efficient upserts into the Transaction model while storing the sync cursor for future calls, supporting deeper history for curriculum features like tax simulations.

#### Log Requirements
Junie read <project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md

#### Requirements
**Functional:**
- Create app/services/plaid_transaction_sync_service.rb: Initialize with PlaidItem; call client.transactions_sync with access_token and stored cursor (or nil for initial); parse response (added/modified/removed transactions) and upsert to Transaction model using transaction_id uniqueness.
- Model updates: Add migration for PlaidItem.sync_cursor (string, nullable); handle removals by soft-deletion (add `deleted_at` datetime to Transaction and implement `default_scope { where(deleted_at: nil) }`).
- Logic: For initial call (no cursor), fetch full history; subsequent use 90-day default via cursor; return new cursor for storage post-sync.
- Error handling: Rescue Plaid::ApiError (e.g., ITEM_LOGIN_REQUIRED → enqueue re-auth notification); retry on transient errors (3x with backoff).

**Non-Functional:**
- Performance: Process 1000 transactions <5s; batch upserts with ActiveRecord-import or SQL inserts.
- Security: Encrypt access_token via attr_encrypted; enforce RLS on Transaction queries.
- Rails Guidance: Use plaid-ruby gem (client.transactions_sync); service as PORO or module; migration via `rails g migration AddSyncCursorToPlaidItems sync_cursor:string`.

#### Architectural Context
Builds on Rails MVC: Extend existing sync jobs to call this service; update PlaidItem model (belongs_to :user). No vector DB—feed parsed transactions into FinancialSnapshotJob JSON blobs + static docs (0_AI_THINKING_CONTEXT.md, PRODUCT_REQUIREMENTS.md) for AI prompts via local Ollama wrapper. Aligns with privacy: Local-only execution; supports JPMC/Schwab/Amex/Stellar via sandbox mocks.

#### Acceptance Criteria
- Service call with nil cursor fetches initial history (e.g., ~730 days in sandbox; verify Transaction.count increases accordingly).
- Subsequent call with cursor fetches only new/modified (check no duplicates by transaction_id).
- Removals handled: Marked transactions as deleted (e.g., deleted_at present).
- Cursor stored: Post-sync, PlaidItem.sync_cursor updated.
- Errors logged/handled: E.g., ApiError raises custom exception, logged per junie-log-requirement.md.
- No data loss: Upserts preserve existing fields not in response.
- Sandbox/production toggle: Uses ENV['PLAID_ENVIRONMENT'] for client init.
- Migration applied: Column exists via console (PlaidItem.column_names.include?('sync_cursor')).

#### Test Cases
- Unit: spec/services/plaid_transaction_sync_service_spec.rb – it "fetches and upserts initial transactions" { VCR.use_cassette('transactions_sync_initial') { expect { service.call }.to change(Transaction, :count).by(50) } }.
- Integration: spec/models/plaid_item_spec.rb – it "stores cursor after sync" { item = create(:plaid_item); service.call; expect(item.reload.sync_cursor).to be_present }.
- Edge: it "handles removals" { VCR.use_cassette('transactions_sync_remove') { expect { service.call }.to change { Transaction.where(deleted_at: nil).count }.by(-1) } }.

#### Workflow
Junie, pull from main, create branch `feature/full-fetch-0020-transactions-sync-service`. Ask questions and build a plan before execution. Use Claude Sonnet 4.5 in RubyMine. Commit only green code (run bin/rails test, RuboCop). Push for review. Confirm with Eric before proceeding to next PRD.

Next steps: After merge, ready for 0030-Webhook-Controller-Setup-PRD? Any Junie questions to append?