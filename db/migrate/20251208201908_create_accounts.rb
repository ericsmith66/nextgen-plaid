class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.references :plaid_item, null: false, foreign_key: true
      t.string :account_id
      t.string :mask
      t.string :name
      t.string :type
      t.string :subtype
      t.decimal :current_balance
      t.string :iso_currency_code

      t.timestamps
    end
  end
end
