# NextGen Plaid (formerly Bergen-Plaid)

Secure, encrypted Plaid integration for **NextGen Wealth Advisor** — built on Rails 8.0.4 + Plaid gem v36+.

Pulls brokerage accounts, positions, balances, and transactions from any institution (Chase, Schwab, Amex, etc.) with **zero secrets in code**.

**Status**: Sandbox fully working — holdings display live on dashboard  
**Production-ready**: Just flip `PLAID_ENV=production` and your prod keys

## Features
- Plaid Link v2 with correct OAuth flow
- Encrypted `access_token` using `attr_encrypted` + per-record random IV
- Full data sync (holdings, transactions, liabilities) via background jobs
- **Daily auto-sync** at 3am via Solid Queue recurring jobs
- Clean dashboard showing real-time portfolio with data counts
- Owner-only Mission Control with full sync visibility and manual triggers
- Per-product sync timestamps (holdings, transactions, liabilities)
- No SmartProxy, no public endpoints required
- Works 100% on localhost

## Mission Control (Admin)

A private, owner-only control panel to manage Plaid items and background syncs.

### Access
- URL: `/mission_control`
- Guarded by `before_action :require_owner`
- Owner email: set `OWNER_EMAIL` env var (defaults to `ericsmith66@me.com`).

### What you can do
- **Global Status Dashboard** — see every `PlaidItem` with per-product sync timestamps:
  - Institution, Item ID, Status (green/red indicator)
  - Holdings Synced At, Transactions Synced At, Liabilities Synced At (relative time + absolute timestamp)
  - Account/Position/Transaction counts
- **Refresh Everything Now** (green button) — one-click full sync: enqueues holdings + transactions + liabilities jobs for all items.
- **Sync Holdings Now** — enqueues `SyncHoldingsJob` for all items.
- **Sync Transactions Now** — enqueues `SyncTransactionsJob` for all items (730 days of transactions + recurring streams).
- **Sync Liabilities Now** — enqueues `SyncLiabilitiesJob` for all items (credit cards, loans, mortgages).
- **Re-link** an item (Plaid Link update mode) — click "Re-link" and complete Link; a holdings sync is auto-enqueued.
- **Nuke Everything** — deletes all Plaid data (use with care; confirmation prompt shown).
- **Real-time sync logs** (last 20) — auto-refreshes every 5s with status colors and `job_id`. Toast notifications on success.

### Daily Auto-Sync
- **Solid Queue recurring job** runs at **3am every day** (configured in `config/recurring.yml`).
- Automatically enqueues full sync (holdings + transactions + liabilities) for all items.
- Ensures data stays fresh without manual intervention.

### Empty state
- If there are no Plaid items yet, the page shows guidance to link an account from the customer dashboard.

### Notes
- Logs are persisted in `sync_logs` with `job_type`, `status`, optional `error_message`, and `job_id`.
- Per-product timestamps: `holdings_synced_at`, `transactions_synced_at`, `liabilities_synced_at` updated on success.
- Each job runs independently; one failure doesn't block others (graceful error handling).
- Secrets are filtered from logs (`filter_parameter_logging.rb`).

## Production Setup (PROD-TEST-01)

### 1. Configure Environment
Create a `.env.production` file at the root of the project and fill in your keys (use `.env.production.example` as a template). This file is ignored by git for security.

```bash
RAILS_ENV=production
PLAID_ENV=production
PLAID_CLIENT_ID=your_production_client_id
PLAID_SECRET=your_production_secret
PLAID_REDIRECT_URI=https://api.higroundsolutions.com/plaid_oauth/callback
ENCRYPTION_KEY=64_char_hex_string_here
SEED_USER_PASSWORD=secure_password_for_seeded_user # (or PROD_USER_PASSWORD)
NEXTGEN_PLAID_DATABASE_PASSWORD=your_db_password
SEED_LOOKUPS=true # (optional, for first run)
```

### 2. Database Initialization
```bash
# Install PostgreSQL 16 if needed: brew install postgresql@16
RAILS_ENV=production bin/rails db:prepare
RAILS_ENV=production bin/rails db:create
RAILS_ENV=production bin/rails db:migrate
# Include shards if applicable (db:migrate:cache, etc.)
```

### 3. Production Seeding
```bash
# Seed the test user (ericsmith66@me.com) and optional lookups
RAILS_ENV=production bin/rails prod_setup:seed SEED_PFC=true SEED_TCODES=true
```

### 4. Smoke Test
Verify the configuration without making real API calls:
```bash
RAILS_ENV=production bin/rails prod_setup:smoke_plaid
```

### 5. First Production Run
1. Start the server: `RAILS_ENV=production bin/rails server`
2. Navigate to `/mission_control`
3. Link your first production account.
4. Verify sync via Mission Control logs.

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

