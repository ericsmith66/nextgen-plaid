
# PRD: PROD-TEST 1 - Plaid Production Environment Switch and Database Initialization/Seeding

## Overview
Configure the app for Plaid's production environment to enable real data retrieval of transactions, liabilities, and holdings from institutions like JPMC, Schwab, Amex, and Stellar; initialize and seed the production PostgreSQL database with a test user (ericsmith66@me.com) and optional minimal lookup data for enrichment models. This validates production stability for HNW financial syncing, advancing the virtual family office tutor by ensuring secure, live data feeds into AI/RAG without code overhauls.

## Log Requirements
Junie read <project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md

## Requirements

### Functional
- Plaid Config: Honor `PLAID_ENV=production` in `config/initializers/plaid.rb`; load production keys from env vars (`PLAID_CLIENT_ID`, `PLAID_SECRET`—separate from sandbox, not co-located in same .env files; reference `plaid_prod_access.txt` securely, never commit—ensure `.gitignore` covers it). Use pattern:
  ```
  # config/initializers/plaid.rb
  env_name = ENV.fetch('PLAID_ENV', Rails.env.production? ? 'production' : 'sandbox')
  config = Plaid::Configuration.new
  config.server_index = Plaid::Configuration::Environment[env_name]
  config.api_key['PLAID-CLIENT-ID'] = ENV.fetch('PLAID_CLIENT_ID')
  config.api_key['PLAID-SECRET'] = ENV.fetch('PLAID_SECRET')
  Rails.application.config.x.plaid_client = Plaid::ApiClient.new(config)
  Rails.logger.info("PLAID READY | Env: #{env_name} | client_id?: #{ENV['PLAID_CLIENT_ID'].present?}")
  ```
  Raise clear error if keys missing in production.
- Production Guard: In sync jobs (e.g., `SyncTransactionsJob`, `SyncLiabilitiesJob`, `SyncHoldingsJob`), use Guard A for API calls: `return skip_non_prod! unless Rails.env.production? && ENV['PLAID_ENV'] == 'production'` where `skip_non_prod!` logs a warning (e.g., "Skipping production Plaid call in non-prod env") and creates a SyncLog entry. Allow Guard B for job scheduling/running in non-prod for sandbox tests.
- Retrieval Support: Verify Plaid endpoints `/transactions/get`, `/liabilities/get`, `/investments/holdings/get` function in production using existing models (PlaidItem, Account, Transaction, Position); handle enrichments via `/transactions/enrich` if enabled (behind flag).
- Logging: Log production mode in initializer as above; capture production errors (e.g., rate limits, invalid institutions) in jobs with Rails.logger, including Plaid request_id where available for failures/successes. Use existing PlaidApiCall model to record product/endpoint/costs.
- Database Initialization: Install PostgreSQL locally if needed (`brew install postgresql@16`); create DB role `nextgen_plaid` with permissions; set `.env.production` vars (`NEXTGEN_PLAID_DATABASE_PASSWORD`, optional `username: nextgen_plaid`); run `RAILS_ENV=production rails db:create` for `nextgen_plaid_production` (include shards like _cache, _queue, _cable only if defined in `database.yml`—optional; provide sample `database.yml` snippet in README). Follow with `RAILS_ENV=production rails db:migrate` (including shard paths if applicable, e.g., db/cache_migrate).
- Database Seeding: Update `db/seeds.rb` to seed in production only (`return unless Rails.env.production?`): Limit to single idempotent test User (`User.find_or_create_by!(email: 'ericsmith66@me.com') do |u| u.password = ENV['SEED_USER_PASSWORD'] || 'securepassword123!'; u.password_confirmation = u.password; u.confirmed_at = Time.current end`); optional minimal lookups on demand (e.g., invoke `Rake::Task['uc14:seed_pfc'].invoke if ENV['SEED_PFC'] == 'true'` for PersonalFinanceCategory with entries from Plaid taxonomy CSV like "income_salary", "transfer_investment"; similar for `SEED_TCODES=true` for TransactionCode "adjustment", "purchase"; `SEED_MERCHANT=true` for Merchant samples like "Amazon" via merchant_entity_id—use exact minimal lists from UC-14 tasks/CSV). Add custom rake task `rails prod_setup:seed` to wrap `db:seed` under production env:
  ```
  # lib/tasks/prod_setup.rake
  desc 'Production seed wrapper'
  namespace :prod_setup do
    task seed: :environment do
      abort 'Not in production' unless Rails.env.production?
      Rake::Task['db:seed'].invoke
    end
  end
  ```
- Smoke Task: Add `rails prod_setup:smoke_plaid` that logs environment and credentials presence (no secrets, e.g., "Env: production | Keys present: true/false | request_id_stub: <none>")—no-op in prod to avoid costs; optional sandbox ping if non-prod.
- Integration: Post-setup, run manual sync via Mission Control (`/mission_control`) for test user; ensure RLS isolates data. Mission Control flows (connect/relink/sync) work unchanged; handle `ADDITIONAL_CONSENT_REQUIRED` with existing consent CTA for liabilities.

### Non-Functional
- Security: Encrypt keys/tokens via `attr_encrypted`; ENV-only for passwords (use `.env.production` or platform secrets store); no committed secrets; RLS enabled post-migrate.
- Performance: Syncs <1 min/user; seeding <1 min; idempotent operations (safe reruns).
- Reliability: Jobs idempotent with retries (e.g., `retry_on Plaid::ApiError, wait: :exponentially_longer` for rate limits/outages); DB init/seeding raises on errors; handle no-data gracefully. Include request IDs in logs.
- Rails Guidance: No new models/migrations; use existing `config/database.yml` (PostgreSQL adapter, ENV password—provide sample snippet in README); update README with full production steps (exact env var list, sample `.env.production`, Plaid Dashboard steps to enable products, smoke test script, "First production run" guide).

## Architectural Context
Leverage Rails MVC with PostgreSQL RLS for isolation, Devise auth (seed via Devise), plaid-ruby gem (v36+). Plaid client via env vars in initializer; syncs in background jobs (Solid Queue). Schema: User (Devise), PlaidItem (encrypted token), Account (balances), Transaction (with lookups: PersonalFinanceCategory, TransactionCode, Merchant), Position. Production data feeds FinancialSnapshotJob JSON for AI/RAG (prepend to Ollama prompts via AiFinancialAdvisor service—local Llama 3.1 70B). Avoid vector DBs; use static docs (0_AI_THINKING_CONTEXT.md, PRODUCT_REQUIREMENTS.md). Defer Python sims/UI.

## Acceptance Criteria
- App starts/logs "PLAID READY | Env: production | client_id?: true" on boot with updated env vars (raise clear error if PLAID_CLIENT_ID/SECRET missing in production); includes request_id_stub: <none> if no calls yet.
- Manual sync retrieves/stores real transactions/liabilities/holdings for test PlaidItem (verify in DB via console, with request_id logged).
- Guard blocks non-production syncs (logged warning and SyncLog entry); jobs in non-prod skip production Plaid calls and log warning mentioning guard condition.
- Production DB created/migrated; optional shards present if configured; console connects error-free.
- Seeded User exists (email: ericsmith66@me.com, confirmed); optional lookup seeds behind flags (e.g., PersonalFinanceCategory.count >5 if SEED_PFC=true).
- Idempotent: Rerun db:seed adds no duplicates.
- README updated with production/DB/seeding instructions, env vars, sample .env.production, Plaid Dashboard steps, and "First production run" guide.
- No leaks: Logs/DB inspected for sensitive data; errors handled (e.g., rate limit retry with exponential backoff).
- `rails prod_setup:smoke_plaid` logs env and keys presence correctly.
- `RAILS_ENV=production rails db:seed` creates the test user idempotently; optional lookup seeds behind flags.

## Test Cases
- Unit (Minitest): Mock env vars to test initializer chooses correct Plaid environment, sets `Plaid::Configuration::Environment['production']`, and logs correctly; test seeds.rb snippets (assert User.exists?, optional lookup counts if flagged); when PLAID_CLIENT_ID/SECRET missing, initializer raises clear error in production only.
- Integration (safe mock): VCR cassette for minimal production call path; assert data in Transaction/Position post-sync, correct client env used; run `RAILS_ENV=production rails db:seed` and verify counts; seeds produce user exactly once across reruns.
- Edge: Invalid env → no sync/log/SyncLog; existing user → skip seed; rate limit → retry.
- DB: Verify `nextgen_plaid_production` exists post-db:create; migrations applied.
- Smoke: Run `rails prod_setup:smoke_plaid` in prod env; assert logs match expected (e.g., "Env: production, Keys present: true").
- Example: `assert_equal 'production', Rails.application.config.x.plaid_client.configuration.server_index`; `assert_equal 1, User.where(email: 'ericsmith66@me.com').count`.

## Workflow
Junie: Use Claude Sonnet 4.5 in RubyMine. Pull from master: `git pull origin main`. Create branch: `git checkout -b feature/prod-test-1-plaid-production-switch`. Ask questions and build a plan before coding (e.g., "Confirm production keys separate? Exact minimal lookup entries for PersonalFinanceCategory from UC-14? DB shards required based on database.yml?"). Implement in atomic commits; run `rails test` and manual tests (e.g., production console, Mission Control sync). Commit only green code; PR to main.

Next steps: Implement updated PRD, then test a real sync with seeded user. Questions: Confirm if UC-14 rake tasks exist in lib/tasks (repo browse showed insufficient content—paste if available)? DB shards confirmed in database.yml (include migration steps for _cache, _queue, _cable).

Answers to Junie's Open Questions:

- Lookup seeding (PFC/TransactionCodes): Only when flags like `SEED_PFC=true`/`SEED_TCODES=true` (not default in production). Reuse existing UC-14 rake tasks (e.g., `uc14:seed_pfc`, `uc14:seed_transaction_codes`) to seed from Plaid CSV on demand. For minimal entries if needed, use Plaid's standard lists:
    - PFC: Primary/detailed categories like INCOME_DIVIDENDS ("Dividends from investment accounts"), INCOME_WAGES ("Income from salaries, gig-economy work, and tips earned"), etc. (full list from https://plaid.com/documents/transactions-personal-finance-category-taxonomy.csv includes ~100 entries grouped by primaries like INCOME, TRANSFER_IN, etc.).
    - Transaction Codes: Enums like "adjustment" ("Bank adjustment"), "atm" ("Cash deposit or withdrawal via an automated teller machine"), "bank charge" ("Charge or fee levied by the institution"), "bill payment" ("Payment of a bill"), "cash" ("Cash deposit or withdrawal"), "cashback" ("Cash withdrawal while making a debit card purchase"), "cheque" ("Document ordering the payment of money to another person or organization"), "direct debit" ("Automatic withdrawal of funds initiated by a third party at a regular interval"), "interest" ("Interest earned or incurred"), "purchase" ("Purchase made with a debit or credit card"), "standing order" ("Payment instructed by the account holder to a third party at a regular interval"), "transfer" ("Transfer of money between accounts"), null ("No transaction code").
    - Merchants: Sample entries like "Amazon" (merchant_entity_id: "VQ90wKM5DgnA8LzA5ymwPuE5rovorjCZAxLR5" or similar from Plaid enrich; limit to 5-10 common ones if no UC-14 CSV).

- Add smoke task `rails prod_setup:smoke_plaid`: Yes, implement it to log environment and credentials presence (no secrets, e.g., "Env: production | Keys present: true"). In prod, avoid pinging real endpoints to prevent costs; use a no-op check or sandbox-only ping if non-prod.

### Answers to Open Questions (Minor)
1) Database shards: Yes, `_cache`, `_queue`, and `_cable` are configured in `config/database.yml` (confirmed via repo file: production block defines primary, cache, queue, cable with separate databases and migrations_paths like db/cache_migrate). Keep the steps in README, but clarify they apply only if shards are defined (as they are here).

2) Smoke task output destination: Add `puts` on STDOUT for CLI runs in addition to Rails.logger, to improve usability in terminal (e.g., `puts "Env: #{env_name} | Keys present: #{ENV['PLAID_CLIENT_ID'].present?} | request_id_stub: <none>"`).

3) README section: Add the short “First production run” checklist directly in README during implementation (update README.md in the PR with the new “Production Setup” section, including the checklist: e.g., 1. Export env vars from .env.production, 2. rails db:create, 3. rails db:migrate, 4. rails prod_setup:seed, 5. rails s, 6. rails prod_setup:smoke_plaid).

### Responses to Nits / Suggested Micro-Tweaks
- Initializer log line: Agreed—update to structured JSON: `Rails.logger.info({ event: "plaid.ready", env: env_name, client_id_present: ENV['PLAID_CLIENT_ID'].present? }.to_json)`.
- Guard helper: Document in PRD: `skip_non_prod!` writes a SyncLog entry (fields: job_type: e.g., 'transactions', status: 'skipped', message: 'Non-prod env guard') and logs a warning via Rails.logger.
- Smoke task: Explicitly state in PRD/code: "In production, do not invoke any API calls; log only." (e.g., if Rails.env.production?, skip any ping and just check/log env/keys).
- Seeds: Add note in PRD: "Ensure password aligns with Devise config (e.g., minimum length/complexity if enforced; sample 'securepassword123!' meets defaults)."

Next steps: Implement updated PRD with these tweaks; merge after green tests. Questions: None—proceed.
