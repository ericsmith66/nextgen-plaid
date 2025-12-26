### PRD: 0030-Webhook-Controller-Setup-PRD

#### Overview
Create a dedicated PlaidWebhookController to securely receive, verify, and process Plaid webhooks for transactions, holdings, and liabilities updates, enqueuing targeted sync jobs based on event types (e.g., SYNC_UPDATES_AVAILABLE for transactions). This enables real-time data refreshes while ensuring privacy and reliability for family office curriculum insights.

#### Log Requirements
Junie read <project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md

#### Requirements
**Functional:**
- Add app/controllers/plaid_webhook_controller.rb: POST route /plaid/webhook; parse JSON payload using plaid-ruby (e.g., verify with webhook_code and item_id); handle key events: TRANSACTION (SYNC_UPDATES_AVAILABLE → enqueue transaction sync), HOLDINGS:DEFAULT_UPDATE/INVESTMENTS_TRANSACTIONS:DEFAULT_UPDATE → enqueue holdings refresh, DEFAULT_UPDATE (with account_ids) → enqueue liabilities refresh.
- Verification: Implement HMAC signature check using PLAID_WEBHOOK_VERIFICATION_KEY or plaid-ruby helpers; IP whitelisting optional via ENV.
- Enqueuing: Use Solid Queue to jobify syncs (e.g., SyncTransactionsJob.perform_later(plaid_item_id)); update PlaidItem.last_webhook_at on success.
- Error handling: Return 200 OK always (Plaid requirement); log invalid signatures/payloads to DLQ (e.g., new WebhookLog model with JSONB payload); rescue unknown events gracefully.

**Non-Functional:**
- Performance: Handle webhook in <200ms; no heavy processing in controller—defer to jobs.
- Security: Skip CSRF for webhook route (protect_from_forgery except: :create); RLS not needed (no DB reads beyond find_by_item_id); encrypt sensitive payload fields if stored. Use Plaid's HMAC verification; ensure compatibility with ngrok/Cloudflare Tunnel.
- Rails Guidance: Route as post 'plaid/webhook', to: 'plaid_webhook#create'; use ApplicationController subclass; migration for WebhookLog if DLQ needed (rails g model WebhookLog payload:jsonb event_type:string status:string).

#### Architectural Context
Aligns with Rails MVC: New controller integrates with existing services (e.g., call PlaidTransactionSyncService from jobs); update PlaidItem model for last_webhook_at (add migration: datetime, default nil). Supports institution variances (e.g., Chase webhook delays). For AI/RAG: Refreshed data enhances FinancialSnapshotJob JSON blobs + static docs (0_AI_THINKING_CONTEXT.md, PRODUCT_REQUIREMENTS.md) for Ollama prompts via local HTTP wrapper—no cloud calls.

#### Acceptance Criteria
- Webhook POST with valid payload enqueues correct job (e.g., TRANSACTION event → SyncTransactionsJob in queue).
- HMAC verification passes for valid signatures (test with Plaid sandbox /sandbox/item/fire_webhook); fails/rejects invalid.
- last_webhook_at updated on PlaidItem post-processing.
- Always returns 200 OK, even on errors; errors logged to DLQ/WebhookLog.
- Handles all scoped events (TRANSACTION, HOLDINGS, DEFAULT_UPDATE); ignores unrelated.
- No data exposure: Payload not stored unencrypted; logs redacted.
- Sandbox testable: Use /sandbox/fire_webhook to simulate events.

#### Test Cases
- Unit: spec/controllers/plaid_webhook_controller_spec.rb – it "verifies and enqueues on valid TRANSACTION webhook" { post plaid_webhook_path, params: valid_payload; expect(response).to have_http_status(200); expect(SyncTransactionsJob).to have_been_enqueued.with(item_id) } (use WebMock for no external calls).
- Integration: spec/services/plaid_webhook_service_spec.rb (if extracted) – it "processes HOLDINGS update" { service.process(payload); expect(PlaidItem.last.last_webhook_at).to be_present }.
- Edge: it "logs but responds OK on invalid signature" { post with invalid_hmac; expect(WebhookLog.last.status).to eq('failed') }.

#### Workflow
Junie, pull from main, create branch `feature/full-fetch-0030-webhook-controller-setup`. Ask questions and build a plan before execution. Use Claude Sonnet 4.5 in RubyMine. Commit only green code (run bin/rails test, RuboCop). Push for review. Confirm with Eric before proceeding to next PRD.

Next steps: After merge, ready for 0040-Daily-Sync-Fallback-Job-PRD? Any Junie questions to append?