class AddSecuritiesFieldsToHoldings < ActiveRecord::Migration[8.0]
  def change
    add_column :holdings, :isin, :string
    add_column :holdings, :cusip, :string
    add_column :holdings, :sector, :string
    add_column :holdings, :industry, :string
    
    add_index :holdings, :sector
  end
end
