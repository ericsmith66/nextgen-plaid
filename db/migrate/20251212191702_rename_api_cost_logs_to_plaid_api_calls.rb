class RenameApiCostLogsToPlaidApiCalls < ActiveRecord::Migration[8.0]
  def change
    # Rename table from api_cost_logs to plaid_api_calls
    rename_table :api_cost_logs, :plaid_api_calls
    
    # Remove old indexes first
    remove_index :plaid_api_calls, :api_product if index_exists?(:plaid_api_calls, :api_product)
    
    # Rename api_product to product for consistency (do this BEFORE adding new indexes)
    rename_column :plaid_api_calls, :api_product, :product
    
    # Add endpoint column (PRD 8.2: product + endpoint tracking)
    add_column :plaid_api_calls, :endpoint, :string, null: false, default: 'unknown'
    
    # Add called_at column to match PRD 8 schema (separate from created_at)
    add_column :plaid_api_calls, :called_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    
    # Update indexes per PRD 8 schema (now product column exists)
    add_index :plaid_api_calls, [:product, :called_at]
    add_index :plaid_api_calls, :called_at
  end
end
