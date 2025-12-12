class AddErrorHandlingToPlaidItems < ActiveRecord::Migration[8.0]
  def change
    add_column :plaid_items, :last_error, :text
    add_column :plaid_items, :reauth_attempts, :integer, default: 0
  end
end
