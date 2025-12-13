# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# PRD UI-4: Admin/Parent/Kid users for CRUD testing
puts "Seeding users for UI-4 CRUD operations..."

admin_user = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.roles = "admin"
  u.family_id = "family_001"
end

parent_user = User.find_or_create_by!(email: "parent@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.roles = "parent"
  u.family_id = "family_001"
end

kid_user = User.find_or_create_by!(email: "kid@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.roles = "kid"
  u.family_id = "family_001"
end

puts "Created admin, parent, and kid users for family_001"

# PRD UI-2: Mocked data for Model Inspection Views
puts "Seeding data for UI preview..."

# Create demo user if not exists
user = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.roles = "parent"
  u.family_id = "family_002"
end

# Create a sample PlaidItem
plaid_item = PlaidItem.find_or_create_by!(item_id: "demo_item_001") do |pi|
  pi.access_token = "demo_access_token"
  pi.institution_name = "Demo Bank"
  pi.user = user if PlaidItem.column_names.include?("user_id")
end

# Create sample accounts
investment_account = Account.find_or_create_by!(
  plaid_item: plaid_item,
  account_id: "demo_inv_001"
) do |acc|
  acc.name = "Investment Account"
  acc.type = "investment"
  acc.subtype = "brokerage"
  acc.mask = "1234"
  acc.current_balance = 52500.00
  acc.iso_currency_code = "USD"
end

checking_account = Account.find_or_create_by!(
  plaid_item: plaid_item,
  account_id: "demo_chk_001"
) do |acc|
  acc.name = "Checking Account"
  acc.type = "depository"
  acc.subtype = "checking"
  acc.mask = "5678"
  acc.current_balance = 5000.00
  acc.iso_currency_code = "USD"
end

credit_account = Account.find_or_create_by!(
  plaid_item: plaid_item,
  account_id: "demo_cc_001"
) do |acc|
  acc.name = "Credit Card"
  acc.type = "credit"
  acc.subtype = "credit card"
  acc.mask = "9012"
  acc.current_balance = -2000.00
  acc.iso_currency_code = "USD"
  acc.apr_percentage = 18.99
  acc.min_payment_amount = 50.00
  acc.next_payment_due_date = Date.today + 15.days
  acc.is_overdue = false
  acc.debt_risk_flag = false
end

# Create sample holdings (EWZ ETF as mentioned in PRD)
Holding.find_or_create_by!(
  account: investment_account,
  security_id: "EWZ_001"
) do |h|
  h.name = "iShares MSCI Brazil ETF"
  h.symbol = "EWZ"
  h.quantity = 100
  h.cost_basis = 3200.00
  h.market_value = 3500.00
  h.vested_value = 3500.00
  h.institution_price = 35.00
  h.sector = "Emerging Markets"
  h.type = "etf"
end

Holding.find_or_create_by!(
  account: investment_account,
  security_id: "AAPL_001"
) do |h|
  h.name = "Apple Inc."
  h.symbol = "AAPL"
  h.quantity = 50
  h.cost_basis = 8000.00
  h.market_value = 9000.00
  h.vested_value = 9000.00
  h.institution_price = 180.00
  h.sector = "Technology"
  h.type = "equity"
end

Holding.find_or_create_by!(
  account: investment_account,
  security_id: "MSFT_001"
) do |h|
  h.name = "Microsoft Corporation"
  h.symbol = "MSFT"
  h.quantity = 75
  h.cost_basis = 25000.00
  h.market_value = 28000.00
  h.vested_value = 28000.00
  h.institution_price = 373.33
  h.sector = "Technology"
  h.type = "equity"
end

Holding.find_or_create_by!(
  account: investment_account,
  security_id: "VTI_001"
) do |h|
  h.name = "Vanguard Total Stock Market ETF"
  h.symbol = "VTI"
  h.quantity = 60
  h.cost_basis = 12000.00
  h.market_value = 12000.00
  h.vested_value = 12000.00
  h.institution_price = 200.00
  h.sector = "Diversified"
  h.type = "etf"
end

# Create sample transactions
Transaction.find_or_create_by!(
  account: checking_account,
  transaction_id: "demo_txn_001"
) do |t|
  t.name = "Payroll Deposit"
  t.amount = 5000.00
  t.date = Date.today - 5.days
  t.merchant_name = "Employer Inc"
  t.subtype = "deposit"
  t.category = "Income"
  t.pending = false
  t.payment_channel = "ach"
end

Transaction.find_or_create_by!(
  account: checking_account,
  transaction_id: "demo_txn_002"
) do |t|
  t.name = "Grocery Store"
  t.amount = -150.50
  t.date = Date.today - 3.days
  t.merchant_name = "Whole Foods"
  t.subtype = "purchase"
  t.category = "Food and Drink"
  t.pending = false
  t.payment_channel = "in store"
end

Transaction.find_or_create_by!(
  account: checking_account,
  transaction_id: "demo_txn_003"
) do |t|
  t.name = "Transfer to Investment"
  t.amount = -1000.00
  t.date = Date.today - 2.days
  t.merchant_name = nil
  t.subtype = "transfer"
  t.category = "Transfer"
  t.pending = false
  t.payment_channel = "online"
end

Transaction.find_or_create_by!(
  account: credit_account,
  transaction_id: "demo_txn_004"
) do |t|
  t.name = "Amazon Purchase"
  t.amount = -250.00
  t.date = Date.today - 1.day
  t.merchant_name = "Amazon.com"
  t.subtype = "purchase"
  t.category = "Shopping"
  t.pending = false
  t.payment_channel = "online"
end

Transaction.find_or_create_by!(
  account: credit_account,
  transaction_id: "demo_txn_005"
) do |t|
  t.name = "Credit Card Payment"
  t.amount = 500.00
  t.date = Date.today - 10.days
  t.merchant_name = nil
  t.subtype = "payment"
  t.category = "Payment"
  t.pending = false
  t.payment_channel = "online"
end

# PRD UI-3: Create sample sync logs for mission control viewer
SyncLog.find_or_create_by!(
  plaid_item: plaid_item,
  job_type: "holdings",
  status: "success",
  job_id: "sync_job_001_holdings_success"
) do |sl|
  sl.created_at = Time.current - 2.hours
  sl.error_message = nil
end

SyncLog.find_or_create_by!(
  plaid_item: plaid_item,
  job_type: "transactions",
  status: "success",
  job_id: "sync_job_002_transactions_success"
) do |sl|
  sl.created_at = Time.current - 1.hour
  sl.error_message = nil
end

SyncLog.find_or_create_by!(
  plaid_item: plaid_item,
  job_type: "liabilities",
  status: "failure",
  job_id: "sync_job_003_liabilities_failure"
) do |sl|
  sl.created_at = Time.current - 30.minutes
  sl.error_message = "PRODUCT_NOT_READY: Liabilities product not enabled for this item"
end

SyncLog.find_or_create_by!(
  plaid_item: plaid_item,
  job_type: "holdings",
  status: "failure",
  job_id: "sync_job_004_holdings_failure"
) do |sl|
  sl.created_at = Time.current - 15.minutes
  sl.error_message = "ITEM_LOGIN_REQUIRED: Item requires user re-authentication"
end

SyncLog.find_or_create_by!(
  plaid_item: plaid_item,
  job_type: "transactions",
  status: "started",
  job_id: "sync_job_005_transactions_started"
) do |sl|
  sl.created_at = Time.current - 5.minutes
  sl.error_message = nil
end

SyncLog.find_or_create_by!(
  plaid_item: plaid_item,
  job_type: "holdings",
  status: "success",
  job_id: "sync_job_006_holdings_success"
) do |sl|
  sl.created_at = Time.current - 1.day
  sl.error_message = nil
end

SyncLog.find_or_create_by!(
  plaid_item: plaid_item,
  job_type: "liabilities",
  status: "failure",
  job_id: "sync_job_007_liabilities_failure"
) do |sl|
  sl.created_at = Time.current - 2.days
  sl.error_message = "RATE_LIMIT_EXCEEDED: Too many requests, retry after cooldown"
end

SyncLog.find_or_create_by!(
  plaid_item: plaid_item,
  job_type: "transactions",
  status: "success",
  job_id: "sync_job_008_transactions_success"
) do |sl|
  sl.created_at = Time.current - 3.days
  sl.error_message = nil
end

puts "Seed data created successfully!"
puts "  - #{User.count} users"
puts "  - #{PlaidItem.count} plaid items"
puts "  - #{Account.count} accounts"
puts "  - #{Holding.count} holdings"
puts "  - #{Transaction.count} transactions"
puts "  - #{SyncLog.count} sync logs"
