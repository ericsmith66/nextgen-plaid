class Uc14ExtendTransactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # First create lookup tables so FKs can be added
    unless table_exists?(:personal_finance_categories)
      create_table :personal_finance_categories do |t|
        t.string :primary, null: false
        t.string :detailed, null: false
        t.text   :long_description
        t.timestamps
      end
      add_index :personal_finance_categories, [:primary, :detailed], unique: true, name: "index_pfc_on_primary_and_detailed"
    end

    unless table_exists?(:transaction_codes)
      create_table :transaction_codes do |t|
        t.string :code, null: false
        t.string :name
        t.text   :long_description
        t.timestamps
      end
      add_index :transaction_codes, :code, unique: true
    end

    unless table_exists?(:merchants)
      create_table :merchants do |t|
        t.string :merchant_entity_id, null: false
        t.string :name
        t.string :logo_url
        t.string :website
        t.text   :long_description
        t.timestamps
      end
      add_index :merchants, :merchant_entity_id, unique: true
    end

    # Core/enriched fields on transactions (conditionally add if missing)
    add_column :transactions, :pending_transaction_id, :string unless column_exists?(:transactions, :pending_transaction_id)
    add_column :transactions, :account_owner, :string unless column_exists?(:transactions, :account_owner)
    add_column :transactions, :unofficial_currency_code, :string unless column_exists?(:transactions, :unofficial_currency_code)
    add_column :transactions, :check_number, :string unless column_exists?(:transactions, :check_number)
    add_column :transactions, :datetime, :datetime, precision: 6 unless column_exists?(:transactions, :datetime)
    add_column :transactions, :authorized_date, :date unless column_exists?(:transactions, :authorized_date)
    add_column :transactions, :authorized_datetime, :datetime, precision: 6 unless column_exists?(:transactions, :authorized_datetime)
    add_column :transactions, :original_description, :string unless column_exists?(:transactions, :original_description)
    add_column :transactions, :logo_url, :string unless column_exists?(:transactions, :logo_url)
    add_column :transactions, :website, :string unless column_exists?(:transactions, :website)
    add_column :transactions, :merchant_entity_id, :string unless column_exists?(:transactions, :merchant_entity_id)
    add_column :transactions, :transaction_type, :string unless column_exists?(:transactions, :transaction_type)
    add_column :transactions, :transaction_code, :string unless column_exists?(:transactions, :transaction_code)
    add_column :transactions, :personal_finance_category_icon_url, :string unless column_exists?(:transactions, :personal_finance_category_icon_url)
    add_column :transactions, :personal_finance_category_confidence_level, :string unless column_exists?(:transactions, :personal_finance_category_confidence_level)
    add_column :transactions, :personal_finance_category_version, :string, default: "v2" unless column_exists?(:transactions, :personal_finance_category_version)

    add_column :transactions, :location, :jsonb unless column_exists?(:transactions, :location)
    add_column :transactions, :payment_meta, :jsonb unless column_exists?(:transactions, :payment_meta)
    add_column :transactions, :counterparties, :jsonb unless column_exists?(:transactions, :counterparties)

    add_column :transactions, :dedupe_fingerprint, :string unless column_exists?(:transactions, :dedupe_fingerprint)

    add_reference :transactions, :merchant, foreign_key: true, null: true unless column_exists?(:transactions, :merchant_id)
    unless column_exists?(:transactions, :personal_finance_category_id)
      add_reference :transactions, :personal_finance_category, foreign_key: true, null: true
    end
    add_reference :transactions, :transaction_code, foreign_key: true, null: true unless column_exists?(:transactions, :transaction_code_id)

    # Indexes and constraints (concurrent where applicable)
    add_index :transactions, [:account_id, :transaction_id], unique: true, where: "transaction_id IS NOT NULL", name: "index_txn_on_account_and_transaction_id", algorithm: :concurrently
    add_index :transactions, [:account_id, :dedupe_fingerprint], unique: true, where: "dedupe_fingerprint IS NOT NULL", name: "index_txn_on_account_and_fingerprint", algorithm: :concurrently

    # JSONB GIN indexes
    execute "CREATE INDEX CONCURRENTLY IF NOT EXISTS index_transactions_on_location_gin ON transactions USING gin (location jsonb_path_ops)" 
    execute "CREATE INDEX CONCURRENTLY IF NOT EXISTS index_transactions_on_counterparties_gin ON transactions USING gin (counterparties)"
  end

  def down
    remove_index :transactions, name: "index_txn_on_account_and_transaction_id"
    remove_index :transactions, name: "index_txn_on_account_and_fingerprint"
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_transactions_on_location_gin"
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_transactions_on_counterparties_gin"

    change_table :transactions, bulk: true do |t|
      t.remove :pending_transaction_id, :account_owner, :unofficial_currency_code, :check_number,
               :datetime, :authorized_date, :authorized_datetime, :original_description,
               :logo_url, :website, :merchant_entity_id, :transaction_type, :transaction_code,
               :personal_finance_category_icon_url, :personal_finance_category_confidence_level,
               :personal_finance_category_version, :location, :payment_meta, :counterparties,
               :dedupe_fingerprint, :merchant_id, :personal_finance_category_id, :transaction_code_id
    end

    drop_table :merchants
    drop_table :transaction_codes
    drop_table :personal_finance_categories
  end
end
