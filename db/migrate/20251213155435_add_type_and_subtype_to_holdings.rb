class AddTypeAndSubtypeToHoldings < ActiveRecord::Migration[8.0]
  def change
    add_column :holdings, :type, :string
    add_column :holdings, :subtype, :string
  end
end
