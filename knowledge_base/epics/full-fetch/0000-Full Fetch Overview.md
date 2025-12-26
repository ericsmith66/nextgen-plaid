### Updated Epic Overview: FULL-FETCH (Plaid History Optimization)

#### Goals
Optimize Plaid data pulls across transactions, holdings, and liabilities to capture maximum available history initially (730 days for transactions; current snapshots for holdings/liabilities), then use efficient incrementals where supported (transactions only) to minimize API load/costs. Integrate webhooks for real-time updates, daily fallbacks for reliability, and force options for manual intervention—ensuring robust, privacy-focused syncs for HNW families without over-fetching, conforming to Plaid best practices (e.g., cursor-based for transactions, webhook-driven for holdings/liabilities).

#### Expected Capabilities
- Initial: 730-day transaction history on new Item links (via `days_requested: 730` in `/link/token/create`); current holdings/liabilities snapshots.
- Ongoing: Cursor-based incrementals via `/transactions/sync` (90 days default, triggered by webhooks or daily jobs); full refreshes for holdings (`/investments/holdings/get`) and liabilities (`/liabilities/get`) via webhooks or dailies.
- Real-time: Handle TRANSACTION webhooks (SYNC_UPDATES_AVAILABLE, NEW/UPDATED/REMOVED) for transactions; HOLDINGS:DEFAULT_UPDATE and INVESTMENTS_TRANSACTIONS:DEFAULT_UPDATE for holdings; DEFAULT_UPDATE for liabilities (with account IDs).
- Fallback/Monitoring: Daily cron checks if no webhook in 24h; admin force for full refresh (e.g., `/transactions/refresh`, `/investments/refresh` where supported; re-fetch for liabilities).
- Outcomes: Deeper transaction data for AI/RAG (enriched FinancialSnapshotJob JSONs); efficient holdings/liabilities updates; reduced API calls with error resilience (retries, DLQ logs).

#### Architectural Impact
- Models: Add `sync_cursor` (string) to PlaidItem for transactions; `last_webhook_at` (datetime) globally; optional JSONB for webhook payloads in new WebhookLog model.
- Services: New PlaidTransactionSyncService for /sync parsing/upserts; extend for holdings/liabilities refreshes (e.g., PlaidHoldingsRefreshService using /holdings/get).
- Controllers: New PlaidWebhookController for verification/handling (POST endpoint, HMAC/IP checks via plaid-ruby; handle product-specific events).
- Jobs: Solid Queue/Sidekiq for async webhook processing and daily cron (e.g., via whenever gem); force rake task (e.g., `rake plaid:force_full_sync[item_id,product]`).
- Privacy/Security: RLS on new logs; encrypt cursors if sensitive; no cloud—local processing only.
- Testing: VCR for webhook mocks (/sandbox/fire_webhook); integration specs for end-to-end flows, including institution variances (e.g., Chase TAN support).
- Risks: Webhook delays/unreliability (mitigated by daily fallback); no true incrementals for holdings/liabilities (full pulls increase load—throttle); API rate limits (throttle jobs); no major schema changes—backwards compatible.
- Integration: Ties to existing Plaid schema; enhances AiFinancialAdvisor prompts with fuller data context in snapshots.

#### Atomic PRD Summaries
- **0010-Link-Token-Update-PRD**: Update PlaidController to include `days_requested: 730` in link_token creation for initial transaction history; test with sandbox Item link, ensuring no changes to existing flows.
- **0020-Transactions-Sync-Service-PRD**: Implement PlaidTransactionSyncService using /transactions/sync for cursor-based upserts; add sync_cursor to PlaidItem model via migration; handle initial/full pulls vs. incrementals.
- **0030-Webhook-Controller-Setup-PRD**: Create PlaidWebhookController with HMAC verification; parse and enqueue jobs for TRANSACTION, HOLDINGS, INVESTMENTS_TRANSACTIONS, and DEFAULT_UPDATE events across products.
- **0040-Daily-Sync-Fallback-Job-PRD**: Set up Sidekiq cron job (via whenever) to check last_webhook_at and trigger 90-day transaction syncs or full holdings/liabilities refreshes if overdue; log outcomes.
- **0050-Force-Full-Update-Feature-PRD**: Add rake task and optional Mission Control UI button for product-specific force refreshes (e.g., /transactions/refresh); include safeguards against rate limits.
- **0060-Extend-Holdings-Liabilities-PRD**: Extend services/jobs/webhooks for holdings (/holdings/get full refresh on updates) and liabilities (/liabilities/get); test end-to-end with sandbox webhooks.

Next steps: Ready to generate 0010-Link-Token-Update-PRD? Any insertions needed (e.g., 0005-Pre-Migration-PRD)?