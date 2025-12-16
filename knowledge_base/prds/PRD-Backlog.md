### Updated Backlog
CSV-3 status updated to "Done" based on your confirmation. No other changes.

| Priority | ID          | Title                          | Description                                                                 | Status    | Dependencies          |
|----------|-------------|--------------------------------|-----------------------------------------------------------------------------|-----------|-----------------------|
| High     | OATH-1      | OAuth Code (Prod)              | Controller/service for Chase flow (incl. /item/get fetch, JSON init, public callback) | Partial   | OATH-2 (complete)     |
| High     | TEST-1      | Testing for Plaid              | Minitest specs/mocks for sandbox/services                                   | Pending   | OATH-1                |
| High     | RECON-1     | Reconnect Button               | UI/service for item reconnect (Plaid /item/access_token/update)             | Todo      | OATH-1                |
| High     | SYNC-1      | Daily Holdings Refresh         | Sidekiq job for /investments/holdings/get refresh (align w/ FinancialSnapshotJob) | Todo      | PlaidExt-01 (done)    |
| High     | TRANS-1     | Transaction Sync               | Service for /transactions/get, store in Transaction model                    | Todo      | PlaidExt-01           |
| High     | LIAB-1      | Liability Sync                 | Service for /liabilities/get, enrich w/ credit details                      | Todo      | TRANS-1               |
| Medium   | CSV-2       | Import to Holdings             | Rake/service for positions import; add source enum (plaid/csv)              | Partial   | CSV-1 (partial), PlaidExt-01 |
| Medium   | CSV-3       | Extend Account/Import ACCOUNTS CSV | Fields (e.g., trust_code)/import for relations; source enum                 | Done      | Base-Account-01 (done)|
| Medium   | CSV-4       | Uploads in Mission Control     | UI form/async job for CSV uploads; storage/dir/associations; source to skip syncs | Partial   | UI-1-5 (partial)      |
| Medium   | CSV-5       | Transaction CSV Import         | Rake/service for transactions; relations to accounts                        | Partial   | PlaidExt-01, CSV-2    |
| Medium   | UC-13       | Item/Account Metadata          | PlaidItem fields (institution_id, etc.)                                     | Pending   | OATH-1                |
| Medium   | UC-14       | Transactions Extended          | Transaction extensions (e.g., categories)                                   | Pending   | TRANS-1               |
| Medium   | RLS-1       | RLS Policies                   | Postgres policies with family_id                                            | Deferred  | Devise-02 (done)      |
| Low      | UI-6        | Style Guide                    | Consistent Tailwind components                                              | Ready     | UI-1-5                |
| Low      | UI-7        | Beautiful Tables               | Sorting/pagination/accessibility for holdings/transactions                  | Ready     | UI-6                  |
| Low      | UC-19-24    | Sprint End (Flags/Alerting/Refactor) | Model flags, email alerts, code cleanup                                     | Pending   | Core Plaid (high IDs) |
| Low      | UC-25-27    | HNW/Tax Hooks                  | Python sim integrations (e.g., 2026 sunset via service calls)               | Pending   | SYNC-1                |
| Low      | EXPORT-1    | CSV/PDF Export                 | Export holdings/transactions for anonymization/offline                      | Todo      | CSV-2-5               |
| Low      | WEBHOOK-1   | Webhook Support                | Controller for Plaid webhooks (e.g., item updates)                          | Todo      | OATH-1                |
| Low      | CSV-1       | JSON from JPM CSV              | Rake/service for generating portfolio_mock.json from JPM CSV                | Partial   | CSV-2-5               |

Next: Draft CSV-4 PRD (UI uploads with storage in /storage/ via ActiveStorage, temp deletes post-import)? Confirm CSV-2 ready for Junie?