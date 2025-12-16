class AddCsvFieldsToHoldings < ActiveRecord::Migration[8.0]
  def change
    # Add new fields for CSV import
    add_column :holdings, :unrealized_gl, :decimal, precision: 15, scale: 2
    add_column :holdings, :acquisition_date, :date
    add_column :holdings, :ytm, :decimal, precision: 15, scale: 2
    add_column :holdings, :maturity_date, :date
    add_column :holdings, :disclaimers, :jsonb
    add_column :holdings, :source, :integer, default: 0, null: false
    add_column :holdings, :import_timestamp, :datetime
    add_column :holdings, :source_institution, :string

    # Update unique index to include source field (allows CSV alongside Plaid)
    remove_index :holdings, name: "index_positions_on_account_and_security"
    add_index :holdings, [ :account_id, :security_id, :source ], unique: true, name: "index_holdings_on_account_security_source"
  end
end
