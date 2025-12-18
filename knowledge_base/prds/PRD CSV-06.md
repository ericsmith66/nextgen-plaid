**PRD: CSV-6 – Remove CSV Data via Plaid Items Table**

**Overview**  
Enable safe removal of imported CSV data (accounts, holdings, transactions) from the Mission Control dashboard's Plaid items table, addressing current failures where the remove button attempts Plaid API calls on non-Plaid (CSV-sourced) items. This ties to the vision by ensuring robust data management for privacy modes, allowing users to clear mocked/anonymized data without errors.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards (e.g., structured JSON logs via Rails.logger, audit trails for deletions with user_id/timestamp/redacted item details).

**Requirements**
- **Functional**:
    - Extend PlaidItem model with `source` enum (enum: { plaid: 0, csv: 1 }, default: :plaid) if not already present (migration: add_column :plaid_items, :source, :integer, default: 0).
    - Update CSV import services (from CSV-2/3/5) to create/associate a dummy PlaidItem per import batch if none exists (e.g., PlaidItem.create!(user: current_user, institution_name: 'CSV Import', source: :csv); then link Accounts to it). Retroactively apply to existing CSV data via a one-time rake task (lib/tasks/migrate_csv_to_plaid_items.rake).
    - In MissionControlController#remove_item: Check item.source; if :csv, skip Plaid `/item/remove` API call and directly destroy the PlaidItem (cascading to dependent Accounts, Positions, Transactions). If :plaid, retain existing API call. Log the operation (e.g., "CSV data removed for user #{user.id}"). Flash success ("CSV data removed successfully") or error messages.
    - UI: In the Plaid items table (app/components/mission_control_component.html.erb or equivalent ViewComponent), ensure CSV-sourced items display with "CSV Import" label and the existing Remove button works without failure. Add tooltip: "Removes all associated CSV data".
- **Non-Functional**:
    - Privacy: Ensure cascade-delete respects RLS (only owner can remove); audit log deletions without storing sensitive data.
    - Performance: Use dependent: :destroy on associations; batch deletes if >100 records.
    - Rails Guidance: Use existing routes (post '/mission_control/remove_item/:id'); Service: Refactor remove logic into PlaidItemRemoveService (app/services) for reusability/testing. Handle errors (e.g., ActiveRecord::RecordNotFound) with 404 redirect. Update any VCR cassettes for Plaid mocks to include no-op for CSV.

**Architectural Context**  
Builds on Rails MVC: Extend PlaidItem model (belongs_to :user; has_many :accounts, dependent: :destroy); Account has_many :positions/:transactions, dependent: :destroy. For CSV imports, ensure relations tie to dummy PlaidItem to unify the table view. PostgreSQL RLS/attr_encrypted remains for sensitive fields (e.g., no access_token for CSV items). Integrate with daily FinancialSnapshotJob: Post-removal, queue a snapshot refresh to update JSON blobs for AiFinancialAdvisor (prompt starts with updated context + 0_AI_THINKING_CONTEXT.md). Local Ollama via service for optional post-removal summary (e.g., prompt: "Summarize impact of removed data"). Avoid vector DBs—rely on JSON + static docs.

**Acceptance Criteria**
- CSV-sourced PlaidItem created during import; visible in table with "CSV Import" and functional Remove button.
- Clicking Remove on CSV item deletes PlaidItem + cascaded records (Accounts/Positions/Transactions with source='csv') without Plaid API call; success flash shown.
- Existing Plaid items removal unchanged (API call + destroy).
- Retroactive rake task migrates existing CSV data to dummy PlaidItems; no orphaned records.
- Errors (e.g., non-existent ID) handled with flash alert and redirect to /mission_control.
- Table UI renders cleanly (Tailwind/DaisyUI); no broken buttons/icons for CSV items.
- Works in sandbox (mock CSV import/remove).
- Audit log captures removal event without sensitive details.

**Test Cases**
- Unit (RSpec): PlaidItemRemoveService.call(item: csv_item) → expect{ service.call }.to change{ Account.count }.by(-N); no Plaid API stub called. For plaid_item: stubs Plaid /item/remove, changes count.
- Integration: post '/mission_control/remove_item/:id' (CSV item) → redirects with success; records deleted, log entry created. Error case (invalid ID) → alert flash. Use WebMock/VCR for Plaid mocks (skip for CSV). Test cascade via factory_bot setups.

**Workflow**  
Junie: Ask questions/build plan first. Pull from main, branch `feature/csv-6-remove-csv-data`. Use Claude Sonnet 4.5. Commit only green code (run rspec, rubocop). Merge to main post-review.

