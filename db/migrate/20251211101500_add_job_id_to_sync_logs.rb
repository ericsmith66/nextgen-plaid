class AddJobIdToSyncLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :sync_logs, :job_id, :string
    add_index :sync_logs, [:plaid_item_id, :created_at, :job_id], name: "index_sync_logs_on_item_created_at_job"
  end
end
