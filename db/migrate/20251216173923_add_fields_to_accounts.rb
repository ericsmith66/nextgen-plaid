class AddFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :trust_code, :string
    add_column :accounts, :source, :integer, default: 0
    add_column :accounts, :import_timestamp, :datetime
    add_column :accounts, :source_institution, :string
  end
end
