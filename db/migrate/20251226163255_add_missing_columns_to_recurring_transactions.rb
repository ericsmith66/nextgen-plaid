class AddMissingColumnsToRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_transactions, :category, :string
    # add_column :recurring_transactions, :description, :string # Already exists
    add_column :recurring_transactions, :merchant_name, :string
    add_column :recurring_transactions, :last_amount, :decimal, precision: 14, scale: 4
    add_column :recurring_transactions, :last_date, :date
    add_column :recurring_transactions, :status, :string
  end
end
