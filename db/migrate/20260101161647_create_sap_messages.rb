class CreateSapMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :sap_messages do |t|
      t.references :sap_run, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false, default: ""

      t.timestamps
    end

    add_index :sap_messages, [ :sap_run_id, :created_at ]
  end
end
