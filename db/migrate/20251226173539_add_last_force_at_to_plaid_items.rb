class AddLastForceAtToPlaidItems < ActiveRecord::Migration[8.0]
  def change
    add_column :plaid_items, :last_force_at, :datetime
  end
end
