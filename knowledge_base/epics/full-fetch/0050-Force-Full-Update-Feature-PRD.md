### PRD: 0050-Force-Full-Update-Feature-PRD

#### Overview
Add a force full update mechanism via rake task and optional Mission Control UI button to trigger product-specific refreshes (e.g., /transactions/refresh for 730-day transaction backfill, /investments/refresh for holdings, full /liabilities/get), providing manual control for data staleness or curriculum simulations while throttling to avoid API limits.

#### Log Requirements
Junie read <project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md

#### Requirements
**Functional:**
- Create rake task lib/tasks/plaid.rake: Define plaid:force_full_sync[item_id,product] (product: 'transactions', 'holdings', 'liabilities'); fetch PlaidItem by id, call /transactions/refresh or equivalent (for transactions/holdings; re-sync full for liabilities); then enqueue standard sync service.
- UI addition (optional, admin-only): In Mission Control dashboard (app/views/mission_control/index.html.erb or ViewComponent), add button per PlaidItem/product; POST to new controller action (e.g., PlaidRefreshesController#create) to trigger rake equivalent async via job.
- Safeguards: Rate limit (e.g., max 1/item/day, check last_force_at on PlaidItem); notify on success/failure (e.g., flash or email).
- Extend PlaidItem: Migration for last_force_at (datetime).

**Non-Functional:**
- Performance: Task completes <10s per item; UI responsive <1s.
- Security: Devise admin auth for UI/rake; RLS on PlaidItem access.
- Rails Guidance: rails g task plaid force_full_sync; for UI, use Tailwind/DaisyUI button (e.g., btn-primary); jobify if UI-triggered (ForcePlaidSyncJob.perform_later).

#### Architectural Context
Aligns with Rails MVC: New rake/task integrates with existing services (PlaidTransactionSyncService, etc.); optional controller for UI (app/controllers/plaid_refreshes_controller.rb, route post '/plaid_items/:id/refresh'). Update PlaidItem model. Enhances data for FinancialSnapshotJob JSON blobs + static docs (0_AI_THINKING_CONTEXT.md, PRODUCT_REQUIREMENTS.md) in local Ollama prompts. Supports all institutions; no cloud dependency.

#### Acceptance Criteria
- Rake task triggers refresh: Run plaid:force_full_sync[1,transactions] → calls /transactions/refresh, updates last_force_at, enqueues sync.
- UI button (if implemented): Click enqueues job; flash success.
- Rate limit enforces: Second call same day skips/logs warning.
- Products handled: Transactions/holdings use /refresh; liabilities full re-fetch.
- Logs capture: Per junie-log-requirement.md, e.g., "Force sync initiated for item_id:1, product:transactions".
- No unauthorized access: Non-admin rake/UI fails.
- Sandbox testable: Use /sandbox/item/reset_login to simulate need for refresh.

#### Test Cases
- Unit: spec/tasks/plaid_spec.rb – it "forces transaction refresh" { expect(client).to receive(:transactions_refresh).and_return(mock_response); Rake::Task['plaid:force_full_sync'].invoke(1, 'transactions'); expect(PlaidItem.find(1).last_force_at).to be_present }.
- Integration: spec/requests/plaid_refreshes_spec.rb (if UI) – it "triggers refresh as admin" { sign_in admin; post refresh_path(id:1, product:'holdings'); expect(response).to redirect_to(mission_control_path); expect(enqueued_jobs.size).to eq(1) }.

#### Workflow
Junie, pull from main, create branch `feature/full-fetch-0050-force-full-update-feature`. Ask questions and build a plan before execution. Use Claude Sonnet 4.5 in RubyMine. Commit only green code (run bin/rails test, RuboCop). Push for review. Confirm with Eric before proceeding to next PRD.

Next steps: After merge, ready for 0060-Extend-Holdings-Liabilities-PRD? Any Junie questions to append?