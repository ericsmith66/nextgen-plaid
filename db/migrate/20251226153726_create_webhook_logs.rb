class CreateWebhookLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_logs do |t|
      t.jsonb :payload
      t.string :event_type
      t.string :status
      t.references :plaid_item, null: true, foreign_key: true

      t.timestamps
    end
  end
end
