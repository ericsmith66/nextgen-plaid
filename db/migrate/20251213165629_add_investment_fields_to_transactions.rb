class AddInvestmentFieldsToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :fees, :decimal, precision: 15, scale: 8
    add_column :transactions, :subtype, :string
    add_column :transactions, :price, :decimal, precision: 15, scale: 8
    add_column :transactions, :dividend_type, :string
    add_column :transactions, :wash_sale_risk_flag, :boolean, default: false
    
    add_index :transactions, :subtype
  end
end
