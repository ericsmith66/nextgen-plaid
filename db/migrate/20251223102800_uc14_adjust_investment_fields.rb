class Uc14AdjustInvestmentFields < ActiveRecord::Migration[8.0]
  def up
    # Align precisions/scales with PRD UC-14
    change_column :transactions, :fees, :decimal, precision: 15, scale: 2
    change_column :transactions, :price, :decimal, precision: 15, scale: 6
    add_column    :transactions, :quantity, :decimal, precision: 20, scale: 6 unless column_exists?(:transactions, :quantity)

    add_index :transactions, :subtype unless index_exists?(:transactions, :subtype)
  end

  def down
    change_column :transactions, :fees, :decimal, precision: 15, scale: 8
    change_column :transactions, :price, :decimal, precision: 15, scale: 8
    remove_column :transactions, :quantity
  end
end
