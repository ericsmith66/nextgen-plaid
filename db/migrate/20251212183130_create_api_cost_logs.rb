class CreateApiCostLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :api_cost_logs do |t|
      t.string :api_product, null: false
      t.string :request_id
      t.integer :transaction_count, default: 0
      t.integer :cost_cents, default: 0

      t.timestamps
    end
    
    add_index :api_cost_logs, :api_product
    add_index :api_cost_logs, :created_at
  end
end
