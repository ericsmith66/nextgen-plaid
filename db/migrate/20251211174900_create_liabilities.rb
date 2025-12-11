class CreateLiabilities < ActiveRecord::Migration[8.0]
  def change
    create_table :liabilities do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :liability_id, null: false
      t.string  :liability_type
      t.decimal :current_balance, precision: 14, scale: 4
      t.decimal :min_payment_due, precision: 14, scale: 4
      t.decimal :apr_percentage, precision: 6, scale: 4
      t.date    :payment_due_date

      t.timestamps

      t.index [:account_id, :liability_id], unique: true
    end
  end
end
