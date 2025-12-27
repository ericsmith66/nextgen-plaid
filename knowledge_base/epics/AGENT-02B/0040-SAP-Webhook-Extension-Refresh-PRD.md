### 0040-SAP-Webhook-Extension-Refresh-PRD.md

#### Overview
This PRD extends the existing webhook controller (from README /plaid/webhook) to handle post-merge events on knowledge_base/ changes, triggering sap_inventory.rake for RAG refresh and backlog updates. Ties to vision: Ensures fresh context in SAP, preventing stale PRDs for Plaid liability/enrichment features.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All webhook events, triggers, and errors must be logged in `agent_logs/sap.log` with structured entries (e.g., timestamp, event type, rake outcome). Rotate logs daily via existing rake.

#### Requirements
**Functional Requirements:**
- **Webhook Extension**: Add handling in PlaidWebhookController for GitHub post-merge payloads (e.g., if event == 'push' and branch == 'main' and files.include?('knowledge_base/'), enqueue rake sap:inventory).
- **Signature Validation**: Use `GITHUB_WEBHOOK_SECRET` from `.env` to verify GitHub payload signatures. Return 401/422 on failure.
- **Trigger Logic**: Use Solid Queue to run rake; update backlog via SapAgent #update_backlog after inventory refresh.
- **Event Parsing**: Parse payload for changed files (regex /knowledge_base/), ignore non-relevant pushes.
- **Error Handling**: Log failures without crashing. Return appropriate HTTP status codes.

**Non-Functional Requirements:**
- Performance: Handling <100ms; rake trigger async.
- Security: Verify GitHub signature (mandatory). RLS on controller.
- Compatibility: Rails 7+; use ActionController for extension.
- Privacy: No data exposure in webhooks.

#### Architectural Context
Extend existing PlaidWebhookController (app/controllers/plaid_webhook_controller.rb) with new action or before_action for GitHub events. Integrate with Epic 1 router for logging; use Solid Queue for async rake. Test with mock payloads (VCR for GitHub). Challenge: Secure verification (use Octokit if needed, but prefer built-in); limit to main branch.

#### Acceptance Criteria
- Webhook handles mock post-merge payload, enqueues rake if knowledge_base/ changed.
- Rake trigger refreshes inventory.json and updates backlog statuses.
- Non-relevant event ignored (no enqueue).
- Invalid payload returns 422 with log.
- Async run succeeds <5s end-to-end.

#### Test Cases
- Unit (RSpec): For controller—mock payload, assert enqueue if match, no enqueue otherwise; test verification failure (422).
- Integration: Post mock curl to webhook, assert rake ran (inventory.json updated); Capybara-like: System spec with javascript: true to simulate webhook post (expect job.performed?), cover AC with scenarios like relevant change (expect backlog updated), irrelevant (no change), invalid (expect response.status == 422); test backlog prune post-refresh.
- Edge: No changes (ignore); failed rake (log error, no crash).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0040-sap-webhook-extension-refresh`). Ask questions and build a plan before coding (e.g., "Payload format for GitHub push? Verification secret location? Enqueue method? Integrate backlog update?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.
