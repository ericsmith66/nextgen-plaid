# PRD: CSV-5 - Transaction CSV Import Service and Model Extensions

## Overview
Extend the Transaction model with additional fields like tran_code and source enum, and implement a rake task/service to import transactions from JPM CSV files (e.g., JPMC Current.csv). This supports mocking transaction history for privacy modes in the virtual family office internship, enabling secure, local-first analysis of cash flows, dividends, and trades for $20-50M families' educational curriculum.

## Requirements
### Functional
- Extend Transaction model with:
    - `cusip`: string, optional.
    - `ticker`: string, optional.
    - `quantity`: decimal(15,2), optional (for trades).
    - `cost_usd`: decimal(15,2), optional.
    - `income_usd`: decimal(15,2), optional.
    - `tran_code`: string, optional.
    - `source`: enum { plaid: 0, csv: 1 }, default: :plaid.
    - `import_timestamp`: datetime, optional.
    - `source_institution`: string, optional (e.g., 'jpmc').
- Create `CsvTransactionsImporter` service (app/services/csv_transactions_importer.rb) to parse CSV and create/update Transaction records linked to an Account (matched via extracted last 4 digits from 'Account Number' to Account.mask).
- Mappings:
    - date: Date.parse('Trade Date') (date; fallback to 'Post Date' if blank).
    - amount: 'Amount USD' (decimal(15,2); positive for credits, negative for debits).
    - description: 'Description' (string).
    - category: Map 'Type' + 'Tran Code Description' to enum (dividend_domestic: 'Dividend' + 'DIV DOMEST', sale: 'Sale', ach_debit: 'ACH Debit', etc.; define enum in model).
    - pending: 'Settlement Date' > Date.today (boolean).
    - cusip: 'Cusip' (string).
    - ticker: 'Ticker' (string).
    - quantity: 'Quantity' (decimal(15,2)).
    - cost_usd: 'Cost USD' (decimal(15,2)).
    - income_usd: 'Income USD' (decimal(15,2)).
    - tran_code: 'Tran Code' (string).
    - source: :csv.
    - source_institution: 'jpmc' (hardcoded).
    - import_timestamp: Time.current.
- Relations: belongs_to :account (extract mask from 'Account Number' e.g., '...7008' → '7008'; match to existing Account); skip if no match (log warning).
- Filtering: Skip rows with irrelevant 'Type' (e.g., 'Memo Debit Tran') or amount == 0; handle negatives for debits naturally.
- Rake task: `rake csv:import_transactions[file_path]` – parses file, calls service, logs to Rails.logger.
- Uniqueness: Scope by account_id + date + amount + description to avoid duplicates; allow CSV alongside Plaid.
- Validation: Presence of date, amount, description; handle blanks/NaN as nil; log skips for invalid parses (e.g., non-date 'Trade Date').

### Non-Functional
- Performance: Use CSV.foreach for streaming; bulk insert via ActiveRecord.import for >100 rows.
- Security: Local file processing only; no external calls. Use attr_encrypted if sensitive fields added later.
- Testing: Minitest for 80% coverage; mock fixtures for CSV.
- Deferrals: No UI (CSV-4); no RLS yet (deferred to RLS-1); generalize for Schwab/Amex/Stellar later; extend categories in UC-14 post-core Plaid.

## Architectural Context
Leverage Rails 7+ MVC: Generate migration (`rails g migration AddFieldsToTransactions cusip:string ticker:string quantity:decimal cost_usd:decimal income_usd:decimal tran_code:string source:integer import_timestamp:datetime source_institution:string`). Add validations/enums to Transaction model (belongs_to :account). Service as PORO for reusability. Integrate with PlaidItem via Account (encrypted tokens). Post-import, queue FinancialSnapshotJob to snapshot JSON for Ollama RAG (AiFinancialAdvisor uses blobs + static docs like 0_AI_THINKING_CONTEXT.md). Use Devise for user scoping (pass current_user to service via rake param or ENV). PostgreSQL single instance with deferred RLS. No vector DB—stick to JSON for AI context.

## Acceptance Criteria
- Rake task imports valid CSV: `Transaction.where(source: :csv).count` matches expected rows (verify in rails c).
- Transactions linked to correct Account via extracted mask match.
- Mappings accurate (e.g., 'Trade Date' "12/31/2025" → Date.parse; 'Amount USD' "2.01" → 2.01; category enum set correctly).
- Filtered rows skipped (e.g., zero amount logs "Skipped row X: Zero amount"); no imports for memos.
- Uniqueness enforced: Duplicate transaction raises validation error.
- Import timestamp set and queryable.
- Source :csv prevents future Plaid overwrites (e.g., TRANS-1 skips).
- No data leakage: All local, no API hits.

## Test Cases
- Unit: test/models/transaction_test.rb – `assert_enum :source`; valid with income_usd; category enum includes 'dividend_domestic'.
- Integration: test/services/csv_transactions_importer_test.rb – Fixture CSV (5 valid, 1 invalid date, 1 irrelevant type); assert_difference 'Transaction.count', 5; errors logged; mock Account match.
- Edge: Empty data rows log "No valid transactions"; malformed CSV rescues, logs error.
```ruby
test "imports valid transaction" do
  account = accounts(:one)  # Assume fixture with mask '7008'
  service = CsvTransactionsImporter.new('test/fixtures/jpmc_current.csv', account: account)
  assert_difference 'Transaction.count', 1 do
    service.call(user: users(:one))
  end
  transaction = Transaction.last
  assert_equal Date.parse('12/31/2025'), transaction.date
  assert_equal 2.01, transaction.amount
  assert_equal :csv, transaction.source
  assert_equal 'jpmc', transaction.source_institution
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

Word count: 812

Next: Draft CSV-1 PRD (JSON from Imports)? Any adjustments?