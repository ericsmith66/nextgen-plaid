class AddSyncCursorToPlaidItems < ActiveRecord::Migration[8.0]
  def change
    add_column :plaid_items, :sync_cursor, :string
  end
end
