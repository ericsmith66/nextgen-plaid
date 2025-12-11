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

ActiveRecord::Schema[8.0].define(version: 2025_12_11_094000) do
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
    t.index ["plaid_item_id", "account_id"], name: "index_accounts_on_item_and_account", unique: true
    t.index ["plaid_item_id"], name: "index_accounts_on_plaid_item_id"
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
    t.index ["user_id", "item_id"], name: "index_plaid_items_on_user_and_item", unique: true
    t.index ["user_id", "item_id"], name: "index_plaid_items_on_user_id_and_item_id", unique: true
    t.index ["user_id"], name: "index_plaid_items_on_user_id"
  end

  create_table "positions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "security_id", null: false
    t.string "symbol"
    t.string "name"
    t.decimal "quantity"
    t.decimal "cost_basis"
    t.decimal "market_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "security_id"], name: "index_positions_on_account_and_security", unique: true
    t.index ["account_id"], name: "index_positions_on_account_id"
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

  add_foreign_key "plaid_items", "users"
  add_foreign_key "positions", "accounts"
end
