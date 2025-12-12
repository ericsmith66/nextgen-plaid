class CreateEnrichedTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :enriched_transactions do |t|
      t.references :transaction, null: false, foreign_key: true, index: { unique: true }
      t.string :merchant_name
      t.string :logo_url
      t.string :website
      t.string :personal_finance_category
      t.string :confidence_level

      t.timestamps
    end
  end
end
