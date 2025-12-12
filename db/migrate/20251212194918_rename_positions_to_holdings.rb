class RenamePositionsToHoldings < ActiveRecord::Migration[8.0]
  def change
    rename_table :positions, :holdings
  end
end
