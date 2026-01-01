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

ActiveRecord::Schema[8.0].define(version: 2025_12_13_155435) do
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
    t.string "trust_code"
    t.integer "source", default: 0
    t.datetime "import_timestamp"
    t.string "source_institution"
    t.jsonb "liability_details"
    t.index ["is_overdue"], name: "index_accounts_on_is_overdue"
    t.index ["plaid_item_id", "account_id"], name: "index_accounts_on_item_and_account", unique: true
    t.index ["plaid_item_id"], name: "index_accounts_on_plaid_item_id"
  end

  create_table "agent_logs", force: :cascade do |t|
    t.string "task_id"
    t.string "persona"
    t.string "action"
    t.text "details"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id", "persona", "action"], name: "index_agent_logs_on_task_id_and_persona_and_action", unique: true
    t.index ["task_id"], name: "index_agent_logs_on_task_id"
    t.index ["user_id"], name: "index_agent_logs_on_user_id"
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
    t.decimal "unrealized_gl", precision: 15, scale: 2
    t.date "acquisition_date"
    t.decimal "ytm", precision: 15, scale: 2
    t.date "maturity_date"
    t.jsonb "disclaimers"
    t.integer "source", default: 0, null: false
    t.datetime "import_timestamp"
    t.string "source_institution"
    t.index ["account_id", "security_id", "source"], name: "index_holdings_on_account_security_source", unique: true
    t.index ["account_id"], name: "index_holdings_on_account_id"
    t.index ["sector"], name: "index_holdings_on_sector"
  end

  create_table "merchants", force: :cascade do |t|
    t.string "merchant_entity_id", null: false
    t.string "name"
    t.string "logo_url"
    t.string "website"
    t.text "long_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_entity_id"], name: "index_merchants_on_merchant_entity_id", unique: true
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

  create_table "personal_finance_categories", force: :cascade do |t|
    t.string "primary", null: false
    t.string "detailed", null: false
    t.text "long_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["primary", "detailed"], name: "index_pfc_on_primary_and_detailed", unique: true
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
    t.string "institution_id"
    t.string "plaid_env"
    t.string "sync_cursor"
    t.datetime "last_webhook_at"
    t.datetime "last_force_at"
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
    t.string "category"
    t.string "merchant_name"
    t.decimal "last_amount", precision: 14, scale: 4
    t.date "last_date"
    t.string "status"
    t.index ["plaid_item_id", "stream_id"], name: "index_recurring_transactions_on_plaid_item_id_and_stream_id", unique: true
    t.index ["plaid_item_id"], name: "index_recurring_transactions_on_plaid_item_id"
  end

  create_table "sap_messages", force: :cascade do |t|
    t.bigint "sap_run_id", null: false
    t.string "role", null: false
    t.text "content", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sap_run_id", "created_at"], name: "index_sap_messages_on_sap_run_id_and_created_at"
    t.index ["sap_run_id"], name: "index_sap_messages_on_sap_run_id"
  end

  create_table "sap_runs", force: :cascade do |t|
    t.bigint "user_id"
    t.text "task"
    t.string "status", default: "pending", null: false
    t.string "phase"
    t.string "model_used"
    t.string "correlation_id", null: false
    t.string "idempotency_uuid"
    t.jsonb "output_json"
    t.string "artifact_path"
    t.string "resume_token"
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["correlation_id"], name: "index_sap_runs_on_correlation_id", unique: true
    t.index ["started_at"], name: "index_sap_runs_on_started_at"
    t.index ["user_id"], name: "index_sap_runs_on_user_id"
  end

  create_table "snapshots", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_snapshots_on_user_id"
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

  create_table "transaction_codes", force: :cascade do |t|
    t.string "code", null: false
    t.string "name"
    t.text "long_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_transaction_codes_on_code", unique: true
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
    t.decimal "fees", precision: 15, scale: 2
    t.string "subtype"
    t.decimal "price", precision: 15, scale: 6
    t.string "dividend_type"
    t.boolean "wash_sale_risk_flag", default: false
    t.string "cusip"
    t.string "ticker"
    t.decimal "quantity", precision: 20, scale: 6
    t.decimal "cost_usd", precision: 15, scale: 2
    t.decimal "income_usd", precision: 15, scale: 2
    t.string "tran_code"
    t.string "source", default: "manual", null: false
    t.datetime "import_timestamp"
    t.string "source_institution"
    t.string "dedupe_key"
    t.string "pending_transaction_id"
    t.string "account_owner"
    t.string "unofficial_currency_code"
    t.string "check_number"
    t.datetime "datetime"
    t.date "authorized_date"
    t.datetime "authorized_datetime"
    t.string "original_description"
    t.string "logo_url"
    t.string "website"
    t.string "merchant_entity_id"
    t.string "transaction_type"
    t.string "transaction_code"
    t.string "personal_finance_category_icon_url"
    t.string "personal_finance_category_confidence_level"
    t.string "personal_finance_category_version", default: "v2"
    t.jsonb "location"
    t.jsonb "payment_meta"
    t.jsonb "counterparties"
    t.string "dedupe_fingerprint"
    t.bigint "merchant_id"
    t.bigint "personal_finance_category_id"
    t.bigint "transaction_code_id"
    t.datetime "deleted_at"
    t.index ["account_id", "dedupe_fingerprint"], name: "index_txn_on_account_and_fingerprint", unique: true, where: "(dedupe_fingerprint IS NOT NULL)"
    t.index ["account_id", "dedupe_key"], name: "index_transactions_on_account_and_dedupe", unique: true
    t.index ["account_id", "transaction_id"], name: "index_transactions_on_account_id_and_transaction_id", unique: true
    t.index ["account_id", "transaction_id"], name: "index_txn_on_account_and_transaction_id", unique: true, where: "(transaction_id IS NOT NULL)"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["counterparties"], name: "index_transactions_on_counterparties_gin", using: :gin
    t.index ["deleted_at"], name: "index_transactions_on_deleted_at"
    t.index ["location"], name: "index_transactions_on_location_gin", opclass: :jsonb_path_ops, using: :gin
    t.index ["merchant_id"], name: "index_transactions_on_merchant_id"
    t.index ["personal_finance_category_id"], name: "index_transactions_on_personal_finance_category_id"
    t.index ["subtype"], name: "index_transactions_on_subtype"
    t.index ["transaction_code_id"], name: "index_transactions_on_transaction_code_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "roles", default: "parent"
    t.string "family_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "webhook_logs", force: :cascade do |t|
    t.jsonb "payload"
    t.string "event_type"
    t.string "status"
    t.bigint "plaid_item_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plaid_item_id"], name: "index_webhook_logs_on_plaid_item_id"
  end

  add_foreign_key "agent_logs", "users"
  add_foreign_key "enriched_transactions", "transactions"
  add_foreign_key "fixed_incomes", "holdings"
  add_foreign_key "holdings", "accounts"
  add_foreign_key "option_contracts", "holdings"
  add_foreign_key "plaid_items", "users"
  add_foreign_key "recurring_transactions", "plaid_items"
  add_foreign_key "sap_messages", "sap_runs"
  add_foreign_key "sap_runs", "users"
  add_foreign_key "snapshots", "users"
  add_foreign_key "sync_logs", "plaid_items"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "merchants"
  add_foreign_key "transactions", "personal_finance_categories"
  add_foreign_key "transactions", "transaction_codes"
  add_foreign_key "webhook_logs", "plaid_items"
end
