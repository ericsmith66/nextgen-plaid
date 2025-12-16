# PRD: CSV-2 - Holdings CSV Import Service and Model Extensions

## Loging
- junie review the log requirements  in knowledge_base/prds/prds-junie-log/junie-log-requirements.md

## Overview
Extend the Holding model (renamed from Position per prior commits) with additional fields like unrealized_gl and source enum, and implement a rake task/service to import holdings from JPM CSV files (e.g., 6002.csv). This enables mocking investment positions for privacy modes in the virtual family office internship, supporting secure, local-first portfolio data for $20-50M families' educational simulations.

## Requirements
### Functional
- Extend Holding model with:
    - `unrealized_gl`: decimal(15,2), optional.
    - `acquisition_date`: date, optional.
    - `isin`: string, optional.
    - `ytm`: decimal(15,2), optional (for fixed income).
    - `maturity_date`: date, optional.
    - `disclaimers`: json, optional (e.g., { cost: 'X' }).
    - `source`: enum { plaid: 0, csv: 1 }, default: :plaid.
    - `import_timestamp`: datetime, optional.
    - `source_institution`: string, optional (e.g., 'jpmc').
- Create `CsvHoldingsImporter` service (app/services/csv_holdings_importer.rb) to parse CSV and create/update Holding records linked to an Account (matched via filename last 4 digits to Account.mask).
- Mappings:
    - symbol: 'Ticker' (string).
    - name: 'Description' (string).
    - security_id: 'CUSIP' (string).
    - type: Map 'Asset Class' to enum (stock: 'Equity', cash_equivalent: 'Fixed Income & Cash' if 'Cash', fixed_income: 'Fixed Income & Cash' else); append 'Asset Strategy Detail' for granularity (e.g., 'Core').
    - quantity: 'Quantity' (decimal(15,2)).
    - cost_basis: 'Cost' (decimal(15,2), total).
    - market_value: 'Value' (decimal(15,2)).
    - price_as_of: DateTime.parse('Pricing Date') (datetime).
    - unrealized_gl: 'Unrealized G/L Amt.' (decimal(15,2)).
    - acquisition_date: Date.parse('Acquisition Date') if present (date).
    - isin: 'ISIN' (string).
    - ytm: 'YTM' (decimal(15,2)).
    - maturity_date: Date.parse('Maturity Date') if present (date).
    - disclaimers: JSON { cost: 'Disclaimers-Cost', quantity: 'Disclaimers-Quantity' } if present.
    - source: :csv.
    - source_institution: 'jpmc' (hardcoded).
    - import_timestamp: Time.current.
- Relations: belongs_to :account (match filename to mask); skip if no matching Account (log warning).
- Filtering: Skip rows where 'Asset Class' in ['FOOTNOTES', 'P', 'W', 'X', 'A', 'C'] or Quantity <= 0 or Ticker blank; handle cash rows as cash_equivalent type (optional: update Account balances if duplicate).
- Rake task: `rake csv:import_holdings[file_path]` – parses file, calls service, logs to Rails.logger.
- Uniqueness: Scope by account_id + security_id + source to allow CSV alongside Plaid.
- Validation: Presence of symbol, quantity, market_value; handle NaN/empty as nil; log skips for invalid parses (e.g., non-numeric 'Value').

### Non-Functional
- Performance: Use CSV.foreach for streaming; bulk insert via ActiveRecord.import for >100 rows.
- Security: Local file processing only; no external calls. Use attr_encrypted if sensitive fields added later.
- Testing: Minitest for 80% coverage; mock fixtures for CSV.
- Deferrals: No UI (CSV-4); no RLS yet (deferred to RLS-1); generalize for Schwab/Amex/Stellar later.

## Architectural Context
Leverage Rails 7+ MVC: Generate migration (`rails g migration AddFieldsToHoldings unrealized_gl:decimal acquisition_date:date isin:string ytm:decimal maturity_date:date disclaimers:json source:integer import_timestamp:datetime source_institution:string`). Add validations/enums to Holding model (belongs_to :account). Service as PORO for reusability. Integrate with PlaidItem via Account (encrypted tokens). Post-import, queue FinancialSnapshotJob to snapshot JSON for Ollama RAG (AiFinancialAdvisor uses blobs + static docs like 0_AI_THINKING_CONTEXT.md). Use Devise for user scoping (pass current_user to service via rake param or ENV). PostgreSQL single instance with deferred RLS. No vector DB—stick to JSON for AI context.

## Acceptance Criteria
- Rake task imports valid CSV: `Holding.where(source: :csv).count` matches expected rows (verify in rails c).
- Holdings linked to correct Account via filename mask match.
- Mappings accurate (e.g., 'Pricing Date' "10/31/2025 11:59:59" parses to datetime; 'Value' "$402,550.12" → 402550.12).
- Filtered rows skipped (e.g., FOOTNOTES not imported; logs "Skipped row X: Footer detected").
- Uniqueness enforced: Duplicate security_id for same account/source raises validation error.
- Import timestamp set and queryable.
- Source :csv prevents future Plaid overwrites (e.g., SYNC-1 skips).
- No data leakage: All local, no API hits.

## Loging 
- junie review the log requirments in knowledge_base/prds/prds-junie-log/junie-log-requirements.md


## Test Cases
- Unit: test/models/holding_test.rb – `assert_enum :source`; valid with unrealized_gl; disclaimers JSON parses without error.
- Integration: test/services/csv_holdings_importer_test.rb – Fixture CSV (5 valid, 1 invalid quantity, 1 footer); assert_difference 'Holding.count', 5; errors logged; mock Account match.
- Edge: Empty data rows log "No valid holdings"; malformed CSV rescues, logs error.
```ruby
test "imports valid holding" do
  account = accounts(:one)  # Assume fixture with mask '6002'
  service = CsvHoldingsImporter.new('test/fixtures/6002.csv', account: account)
  assert_difference 'Holding.count', 1 do
    service.call(user: users(:one))
  end
  holding = Holding.last
  assert_equal 'NVDA', holding.symbol
  assert_equal :csv, holding.source
  assert_equal 'jpmc', holding.source_institution
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
