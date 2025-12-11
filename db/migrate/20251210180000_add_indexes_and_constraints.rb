class AddIndexesAndConstraints < ActiveRecord::Migration[8.0]
  def up
    # Plaid Items
    change_column_null :plaid_items, :item_id, false
    change_column_null :plaid_items, :institution_name, false
    change_column_null :plaid_items, :status, false
    add_index :plaid_items, [:user_id, :item_id], unique: true, name: "index_plaid_items_on_user_and_item"

    # Accounts
    change_column_null :accounts, :account_id, false
    add_index :accounts, [:plaid_item_id, :account_id], unique: true, name: "index_accounts_on_item_and_account"

    # Positions
    change_column_null :positions, :security_id, false
    add_index :positions, [:account_id, :security_id], unique: true, name: "index_positions_on_account_and_security"
  end

  def down
    remove_index :positions, name: "index_positions_on_account_and_security"
    change_column_null :positions, :security_id, true

    remove_index :accounts, name: "index_accounts_on_item_and_account"
    change_column_null :accounts, :account_id, true

    remove_index :plaid_items, name: "index_plaid_items_on_user_and_item"
    change_column_null :plaid_items, :status, true
    change_column_null :plaid_items, :institution_name, true
    change_column_null :plaid_items, :item_id, true
  end
end
