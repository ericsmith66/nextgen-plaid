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

