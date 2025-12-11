class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :transaction_id, null: false
      t.string  :name
      t.decimal :amount, precision: 14, scale: 4
      t.date    :date
      t.string  :category
      t.string  :merchant_name
      t.boolean :pending, default: false
      t.string  :payment_channel
      t.string  :iso_currency_code

      t.timestamps

      t.index [:account_id, :transaction_id], unique: true
    end
  end
end
