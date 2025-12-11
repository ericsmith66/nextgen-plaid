class AddLastHoldingsSyncToPlaidItems < ActiveRecord::Migration[8.0]
  def change
    add_column :plaid_items, :last_holdings_sync_at, :datetime
  end
end
