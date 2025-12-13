# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_13_172715) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "plaid_item_id", null: false
    t.string "account_id", null: false
    t.string "mask"
    t.string "name"
    t.string "type"
    t.string "subtype"
    t.decimal "current_balance"
    t.string "iso_currency_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "persistent_account_id"
    t.decimal "apr_percentage", precision: 15, scale: 8
    t.decimal "min_payment_amount", precision: 15, scale: 8
    t.date "next_payment_due_date"
    t.boolean "is_overdue"
    t.boolean "debt_risk_flag"
    t.index ["is_overdue"], name: "index_accounts_on_is_overdue"
    t.index ["plaid_item_id", "account_id"], name: "index_accounts_on_item_and_account", unique: true
    t.index ["plaid_item_id"], name: "index_accounts_on_plaid_item_id"
  end

  create_table "enriched_transactions", force: :cascade do |t|
    t.bigint "transaction_id", null: false
    t.string "merchant_name"
    t.string "logo_url"
    t.string "website"
    t.string "personal_finance_category"
    t.string "confidence_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["transaction_id"], name: "index_enriched_transactions_on_transaction_id", unique: true
  end

  create_table "fixed_incomes", force: :cascade do |t|
    t.bigint "holding_id", null: false
    t.decimal "yield_percentage", precision: 15, scale: 8
    t.string "yield_type"
    t.date "maturity_date"
    t.date "issue_date"
    t.decimal "face_value", precision: 15, scale: 8
    t.boolean "income_risk_flag", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["holding_id"], name: "index_fixed_incomes_on_holding_id", unique: true
  end

  create_table "holdings", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "security_id", null: false
    t.string "symbol"
    t.string "name"
    t.decimal "quantity", precision: 15, scale: 8
    t.decimal "cost_basis", precision: 15, scale: 8
    t.decimal "market_value", precision: 15, scale: 8
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "vested_value", precision: 15, scale: 8
    t.decimal "institution_price", precision: 15, scale: 8
    t.datetime "institution_price_as_of"
    t.boolean "high_cost_flag", default: false, null: false
    t.string "isin"
    t.string "cusip"
    t.string "sector"
    t.string "industry"
    t.string "type"
    t.string "subtype"
    t.index ["account_id", "security_id"], name: "index_positions_on_account_and_security", unique: true
    t.index ["account_id"], name: "index_holdings_on_account_id"
    t.index ["sector"], name: "index_holdings_on_sector"
  end

  create_table "option_contracts", force: :cascade do |t|
    t.bigint "holding_id", null: false
    t.string "contract_type"
    t.date "expiration_date"
    t.decimal "strike_price", precision: 15, scale: 8
    t.string "underlying_ticker"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["holding_id"], name: "index_option_contracts_on_holding_id", unique: true
  end

  create_table "plaid_api_calls", force: :cascade do |t|
    t.string "product", null: false
    t.string "request_id"
    t.integer "transaction_count", default: 0
    t.integer "cost_cents", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "endpoint", default: "unknown", null: false
    t.datetime "called_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["called_at"], name: "index_plaid_api_calls_on_called_at"
    t.index ["created_at"], name: "index_plaid_api_calls_on_created_at"
    t.index ["product", "called_at"], name: "index_plaid_api_calls_on_product_and_called_at"
  end

  create_table "plaid_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "item_id", null: false
    t.string "institution_name", null: false
    t.text "access_token_encrypted"
    t.text "access_token_encrypted_iv"
    t.string "status", default: "good", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_holdings_sync_at"
    t.datetime "holdings_synced_at"
    t.datetime "transactions_synced_at"
    t.datetime "liabilities_synced_at"
    t.text "last_error"
    t.integer "reauth_attempts", default: 0
    t.index ["user_id", "item_id"], name: "index_plaid_items_on_user_and_item", unique: true
    t.index ["user_id", "item_id"], name: "index_plaid_items_on_user_id_and_item_id", unique: true
    t.index ["user_id"], name: "index_plaid_items_on_user_id"
  end

  create_table "recurring_transactions", force: :cascade do |t|
    t.bigint "plaid_item_id", null: false
    t.string "stream_id", null: false
    t.string "description"
    t.decimal "average_amount", precision: 14, scale: 4
    t.string "frequency"
    t.string "stream_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plaid_item_id", "stream_id"], name: "index_recurring_transactions_on_plaid_item_id_and_stream_id", unique: true
    t.index ["plaid_item_id"], name: "index_recurring_transactions_on_plaid_item_id"
  end

  create_table "sync_logs", force: :cascade do |t|
    t.bigint "plaid_item_id", null: false
    t.string "job_type", null: false
    t.string "status", null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "job_id"
    t.index ["plaid_item_id", "created_at", "job_id"], name: "index_sync_logs_on_item_created_at_job"
    t.index ["plaid_item_id", "created_at"], name: "index_sync_logs_on_plaid_item_id_and_created_at"
    t.index ["plaid_item_id"], name: "index_sync_logs_on_plaid_item_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "transaction_id", null: false
    t.string "name"
    t.decimal "amount", precision: 14, scale: 4
    t.date "date"
    t.string "category"
    t.string "merchant_name"
    t.boolean "pending", default: false
    t.string "payment_channel"
    t.string "iso_currency_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "fees", precision: 15, scale: 8
    t.string "subtype"
    t.decimal "price", precision: 15, scale: 8
    t.string "dividend_type"
    t.boolean "wash_sale_risk_flag", default: false
    t.index ["account_id", "transaction_id"], name: "index_transactions_on_account_id_and_transaction_id", unique: true
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["subtype"], name: "index_transactions_on_subtype"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "enriched_transactions", "transactions"
  add_foreign_key "fixed_incomes", "holdings"
  add_foreign_key "holdings", "accounts"
  add_foreign_key "option_contracts", "holdings"
  add_foreign_key "plaid_items", "users"
  add_foreign_key "recurring_transactions", "plaid_items"
  add_foreign_key "sync_logs", "plaid_items"
  add_foreign_key "transactions", "accounts"
end
