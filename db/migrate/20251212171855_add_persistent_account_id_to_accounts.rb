class AddPersistentAccountIdToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :persistent_account_id, :string
  end
end
