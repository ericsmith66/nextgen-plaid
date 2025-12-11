# NextGen Plaid (formerly Bergen-Plaid)

Secure, encrypted Plaid integration for **NextGen Wealth Advisor** — built on Rails 8.0.4 + Plaid gem v36+.

Pulls brokerage accounts, positions, balances, and transactions from any institution (Chase, Schwab, Amex, etc.) with **zero secrets in code**.

**Status**: Sandbox fully working — holdings display live on dashboard  
**Production-ready**: Just flip `PLAID_ENV=production` and your prod keys

## Features
- Plaid Link v2 with correct OAuth flow
- Encrypted `access_token` using `attr_encrypted` + per-record random IV
- Full holdings sync (accounts + positions) via background job
- Clean dashboard showing real-time portfolio
- No SmartProxy, no public endpoints required
- Works 100% on localhost

## Mission Control (Admin)

A private, owner-only control panel to manage Plaid items and background syncs.

### Access
- URL: `/mission_control`
- Guarded by `before_action :require_owner`
- Owner email: set `OWNER_EMAIL` env var (defaults to `ericsmith66@me.com`).

### What you can do
- See every `PlaidItem` (Institution, Item ID, status, last holdings sync, account/position counts).
- Re-link an item (Plaid Link update mode) — click "Re-link" and complete Link; a holdings sync is auto-enqueued.
- Sync Holdings Now — enqueues `SyncHoldingsJob` for all items.
- Sync Transactions Now — enqueues `SyncTransactionsJob` (placeholder today).
- Nuke Everything — deletes Positions, Accounts, PlaidItems (use with care; confirmation prompt shown).
- View recent sync logs (last 20) — auto-refreshes every 5s with status colors and `job_id`. Toast appears when a new success is detected.

### Empty state
- If there are no Plaid items yet, the page shows guidance to link an account from the customer dashboard.

### Notes
- Logs are persisted in `sync_logs` with `job_type`, `status`, optional `error_message`, and `job_id`.
- `SyncHoldingsJob` updates `plaid_items.last_holdings_sync_at` on success.
- Secrets are filtered from logs (`filter_parameter_logging.rb`).

## Quick Start (Development)

```bash
git clone https://github.com/ericsmith66/nextgen-plaid.git
cd nextgen-plaid
cp .env.example .env

# Generate a 64-character hex key (32 bytes)
openssl rand -hex 32
# → paste the output as ENCRYPTION_KEY in .env

bundle install
bin/rails db:create db:migrate
bin/rails server

Visit http://localhost:3000 → log in with any user (Devise) → click CONNECT BROKERAGE ACCOUNT
Use sandbox credentials:

Phone: 4155550010
Username: user_good
Password: pass_good
MFA: 123456

Holdings appear instantly.


PLAID_CLIENT_ID=your_sandbox_client_id
PLAID_SECRET=your_sandbox_secret
PLAID_ENV=sandbox        # change to "production" when ready
ENCRYPTION_KEY=64_char_hex_string_here   # ← generate with `openssl rand -hex 32`

# Admin (Mission Control)
OWNER_EMAIL=your.owner@example.com       # optional; defaults to ericsmith66@me.com


### `TODO.md` (copy-paste)

```markdown
# NextGen Plaid — TODO

## Done ✅
- Plaid Link working
- Encrypted access_token with random IV
- Holdings sync job
- Dashboard displays accounts + positions
- Clean repo (no bloat)

## Next (1–2 days)
- [ ] Add "Reconnect" button for expired tokens
- [ ] Add daily holdings refresh (Solid Queue cron)
- [ ] Add transaction sync
- [ ] Add liability/credit card sync (Amex)
- [ ] Write tests (RSpec + VCR)

## Later
- [ ] Production approval (Chase/Schwab/Amex)
- [ ] Webhook support for real-time updates
- [ ] Multi-user support
- [ ] Export to CSV/PDF
- [ ] Deploy to Fly.io / Render

