class CreateSyncLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_logs do |t|
      t.references :plaid_item, null: false, foreign_key: true
      t.string :job_type, null: false
      t.string :status, null: false
      t.text :error_message

      t.timestamps
    end

    add_index :sync_logs, [:plaid_item_id, :created_at]
  end
end
