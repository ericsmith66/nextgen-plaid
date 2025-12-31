class CreateSapRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :sap_runs do |t|
      t.references :user, null: true, foreign_key: true
      t.text :task
      t.string :status, null: false, default: "pending"
      t.string :phase
      t.string :model_used
      t.string :correlation_id, null: false
      t.string :idempotency_uuid
      t.jsonb :output_json
      t.string :artifact_path
      t.string :resume_token
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :sap_runs, :correlation_id, unique: true
    add_index :sap_runs, :started_at
  end
end