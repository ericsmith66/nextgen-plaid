### PRD: 0060-Extend-Holdings-Liabilities-PRD

#### Overview
Extend sync logic, webhooks, and jobs to support full refreshes for holdings (/investments/holdings/get) and liabilities (/liabilities/get), using webhook events for triggers and daily fallbacks for reliability, ensuring complete data for curriculum areas like asset allocation and debt prioritization without true incrementals (per Plaid best practices for these products).

#### Log Requirements
Junie read <project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md

#### Requirements
**Functional:**
- Create/extend services: app/services/plaid_holdings_sync_service.rb for /investments/holdings/get (parse/upsert to Position/Security models by security_id); app/services/plaid_liabilities_sync_service.rb for /liabilities/get (parse/upsert to Liability model or JSONB in Account, handling credit/mortgage details).
- Webhook integration: In PlaidWebhookController, add handling for HOLDINGS:DEFAULT_UPDATE/INVESTMENTS_TRANSACTIONS:DEFAULT_UPDATE → enqueue holdings sync; DEFAULT_UPDATE (filter by account subtypes) → enqueue liabilities sync.
- Daily/job updates: Extend DailyPlaidSyncJob to include holdings/liabilities full pulls if last_webhook_at overdue; update force rake/UI to support these products.
- Error handling: Rescue Plaid::ApiError (e.g., PRODUCT_NOT_READY → retry later); log full/partial successes.

**Non-Functional:**
- Performance: Full holdings sync <10s for 500 positions; liabilities <5s per account; batch upserts.
- Security: Encrypt sensitive fields (e.g., liability details via attr_encrypted); RLS on new/updated models.
- Rails Guidance: Use plaid-ruby (client.investments_holdings_get, client.liabilities_get); migrations for any new fields (e.g., rails g migration AddLiabilityDetailsToAccounts details:jsonb); services as POROs.

#### Architectural Context
Aligns with Rails MVC: Extend existing PlaidItem/Account/Position models (add associations if needed, e.g., Account.has_one :liability_details via JSONB); integrate with webhook controller and daily jobs. Supports institutions (JPMC/Schwab/Amex/Stellar) via sandbox. For AI/RAG: Enriched holdings/liabilities feed into FinancialSnapshotJob JSON blobs (e.g., totals, risks) + static docs (0_AI_THINKING_CONTEXT.md, PRODUCT_REQUIREMENTS.md) for local Ollama prompts—no vector upgrades.

#### Acceptance Criteria
- Holdings service fetches/upserts data: Sandbox call populates Position.market_value, etc.
- Liabilities service handles subtypes: Parses credit details into JSONB; verifies in DB.
- Webhook events trigger correctly: HOLDINGS update enqueues HoldingsSyncJob.
- Daily job includes products: Overdue triggers full pulls for holdings/liabilities.
- Force feature extended: rake plaid:force_full_sync[1,holdings] calls /investments/refresh if supported, else full get.
- No duplicates: Upserts by unique IDs (e.g., account_id for liabilities).
- Logs comprehensive: Per junie-log-requirement.md, e.g., "Synced 20 holdings for item_id:1".
- End-to-end sandbox: Fire webhook → job → data updated.

#### Test Cases
- Unit: spec/services/plaid_holdings_sync_service_spec.rb – it "parses and upserts holdings" { VCR.use_cassette('holdings_get') { expect { service.call }.to change(Position, :count).by(10) } }.
- Integration: spec/jobs/daily_plaid_sync_job_spec.rb – it "triggers liabilities refresh on overdue" { create(:plaid_item, last_webhook_at: 2.days.ago); expect { job.perform }.to have_enqueued_job(PlaidLiabilitiesSyncJob) }.

#### Workflow
Junie, pull from main, create branch `feature/full-fetch-0060-extend-holdings-liabilities`. Ask questions and build a plan before execution. Use Claude Sonnet 4.5 in RubyMine. Commit only green code (run bin/rails test, RuboCop). Push for review. Confirm with Eric before proceeding to next PRD/epic.

Next steps: Epic complete—merge and test full flow? Any Junie questions to append?