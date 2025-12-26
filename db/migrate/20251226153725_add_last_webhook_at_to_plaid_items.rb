class AddLastWebhookAtToPlaidItems < ActiveRecord::Migration[8.0]
  def change
    add_column :plaid_items, :last_webhook_at, :datetime
  end
end
