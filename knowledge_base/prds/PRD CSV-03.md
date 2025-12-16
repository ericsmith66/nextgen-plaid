# PRD: CSV-3 - Extend Account Model and Import ACCOUNTS CSV

## Overview
Extend the Account model with additional fields like trust_code and source enum, and implement a rake task/service to import accounts from a manually created ACCOUNTS.csv file. This supports mocking account data for privacy modes in the virtual family office internship, enabling secure, local-first portfolio simulations for $20-50M families without immediate Plaid dependency.

## Requirements
### Functional
- Extend Account model with:
    - `trust_code`: string, optional (e.g., 'SFRT' for trusts).
    - `source`: enum { plaid: 0, csv: 1 }, default: :plaid.
    - `import_timestamp`: datetime, optional.
    - `source_institution`: string, optional (e.g., 'jpmc').
- Create `CsvAccountsImporter` service (app/services/csv_accounts_importer.rb) to parse CSV and create/update Account records.
- Mappings:
    - account_id: 'Account Number' (string).
    - mask: Last 4 digits of 'Account Number' (string).
    - name: 'Accounts' (string).
    - type: Map 'Type' to enum (checking: 'Checking', savings: 'Savings', investment: 'Invt Mgmt').
    - subtype: 'Account Description' (string, optional).
    - balances: JSON { current: parse_float('Balance'.gsub(/[$, ]/, '')) }, decimal(15,2).
    - trust_code: 'Trust' (string).
    - source: :csv.
    - source_institution: 'jpmc' (hardcoded).
    - import_timestamp: Time.current.
- Relations: Auto-create mock PlaidItem if none exists (institution_id: 'jpmc', access_token: nil, user_id: current_user.id); link Accounts via belongs_to :plaid_item.
- Rake task: `rake csv:import_accounts[file_path]` – parses file, calls service, logs to Rails.logger.
- Uniqueness: Scope by user_id + account_id + source to allow CSV alongside Plaid.
- Validation: Presence of account_id, mask; enum for type/source. Skip rows with invalid balance or missing 'Account Number'; log errors.

### Non-Functional
- Performance: Use CSV.foreach for streaming; bulk insert via ActiveRecord.import for >50 rows.
- Security: Local file processing only; no external calls. Use attr_encrypted if balances become sensitive.
- Testing: Minitest for 80% coverage; mock fixtures for CSV.
- Deferrals: No UI (CSV-4); no RLS yet (deferred to RLS-1).

## Architectural Context
Leverage Rails 7+ MVC: Generate migration (`rails g migration AddFieldsToAccounts trust_code:string source:integer import_timestamp:datetime source_institution:string`). Add validations/enums to Account model. Service as PORO for reusability. Integrate with PlaidItem (encrypted tokens). Post-import, queue FinancialSnapshotJob to snapshot JSON for Ollama RAG (AiFinancialAdvisor uses blobs + static docs like 0_AI_THINKING_CONTEXT.md). Use Devise for user scoping (pass current_user to service via rake param or ENV). PostgreSQL single instance with deferred RLS. No vector DB—stick to JSON for AI context.

## Acceptance Criteria
- Rake task imports valid CSV: `Account.where(source: :csv).count` matches expected rows (verify in rails c).
- Mock PlaidItem created/linked if missing for 'jpmc'.
- Balances parsed accurately (e.g., "$16,581.33" → { current: 16581.33 }).
- Invalid rows skipped (e.g., $0.00 or parse error logs "Skipped row X: Invalid balance").
- Uniqueness enforced: Duplicate import raises validation error.
- Import timestamp set and queryable.
- Source :csv prevents future Plaid overwrites (e.g., SYNC-1 skips).
- No data leakage: All local, no API hits.

## Test Cases
- Unit: test/models/account_test.rb – `assert_enum :source`; valid with trust_code; balances JSON parses without error.
- Integration: test/services/csv_accounts_importer_test.rb – Fixture CSV (3 valid, 1 invalid, 1 duplicate); assert_difference 'Account.count', 3; errors logged; mock PlaidItem creation.
- Edge: Empty CSV logs "No data"; malformed CSV rescues, logs error.
```ruby
test "imports valid account" do
  service = CsvAccountsImporter.new('test/fixtures/accounts.csv')
  assert_difference 'Account.count', 1 do
    service.call(user: users(:one))
  end
  account = Account.last
  assert_equal '6726', account.account_id
  assert_equal :csv, account.source
  assert_equal 'jpmc', account.source_institution
end
```
### Storage Approach
- **Rake-based Imports (CSV-2/3/5)**: No permanent storage—files are provided via local path arg (e.g., rake csv:import_accounts['/path/to/file.csv']). Service reads/processes in memory (CSV.foreach), then discards. If temp copies needed (e.g., for async), use Rails.root.join('tmp/imports')—create dir if missing, delete post-import.
- **UI Uploads (CSV-4)**: Use ActiveStorage for secure, attached uploads (e.g., attach to new ImportLog model with fields: user_id, file_name, status, errors_json). Store in local disk service (config/storage.yml: local root: <%= Rails.root.join('storage') %>). Limit to .csv, size <10MB; async via Sidekiq (progress via Turbo Streams).

### Post-Import Handling
- **All CSVs**: After successful import, log completion (Rails.logger.info "Import complete: X records added, Y skipped"); queue FinancialSnapshotJob for JSON snapshot. Delete temp files (File.delete if copied); retain in storage only if attached (CSV-4) for audit (e.g., 30-day retention, then purge via cron rake).
- **Error Cases**: Log failures; rollback partial imports (transaction block); notify user (flash/email if UI).

Update PRDs to include this (e.g., add to CSV-4 draft). Defer permanent archive if not critical—focus mocks for privacy.

## Workflow for Junie
Use Claude Sonnet 4.5 (default for Rails reliability). Pull master: `git pull origin main`. Branch: `git checkout -b feature/csv-3-accounts-import`. Plan: Review PRD, ask questions (e.g., "Confirm type enum mappings? Add balances validation?"). Prototype in Ruby (CSV.foreach in service; optional Python pandas script for parse check if preferred—run via terminal). Use generators for migration. Test: `rake test`. Commit green only: `git commit -m "CSV-3: Account extensions and import service"`. Push, open PR.

Word count: 748

Next: Draft CSV-2 PRD? Any adjustments?