class AddLiabilityDetailsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :liability_details, :jsonb
  end
end
