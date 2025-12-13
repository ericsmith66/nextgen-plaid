class StandardizeHoldingsDecimalPrecision < ActiveRecord::Migration[8.0]
  def change
    # Standardize all decimal fields to precision: 15, scale: 8 for consistency
    # This prevents scientific notation issues and ensures precision for HNW portfolios
    change_column :holdings, :quantity, :decimal, precision: 15, scale: 8
    change_column :holdings, :cost_basis, :decimal, precision: 15, scale: 8
    change_column :holdings, :market_value, :decimal, precision: 15, scale: 8
    change_column :holdings, :vested_value, :decimal, precision: 15, scale: 8
    change_column :holdings, :institution_price, :decimal, precision: 15, scale: 8
  end
end
