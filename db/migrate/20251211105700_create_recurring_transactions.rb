class CreateRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_transactions do |t|
      t.references :plaid_item, null: false, foreign_key: true
      t.string  :stream_id, null: false
      t.string  :description
      t.decimal :average_amount, precision: 14, scale: 4
      t.string  :frequency
      t.string  :stream_type

      t.timestamps

      t.index [:plaid_item_id, :stream_id], unique: true
    end
  end
end
