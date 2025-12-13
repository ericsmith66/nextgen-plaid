class AddExtendedFieldsToHoldings < ActiveRecord::Migration[8.0]
  def change
    add_column :holdings, :vested_value, :decimal, precision: 10, scale: 2, null: true
    add_column :holdings, :institution_price, :decimal, precision: 10, scale: 2, null: true
    add_column :holdings, :institution_price_as_of, :datetime, null: true
    add_column :holdings, :high_cost_flag, :boolean, default: false, null: false
  end
end
