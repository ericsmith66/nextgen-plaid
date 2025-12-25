class CreateAgentLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_logs do |t|
      t.string :task_id
      t.string :persona
      t.string :action
      t.text :details
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :agent_logs, :task_id
    add_index :agent_logs, [:task_id, :persona, :action], unique: true
  end
end
