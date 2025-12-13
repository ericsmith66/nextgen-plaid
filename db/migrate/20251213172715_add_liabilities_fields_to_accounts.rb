class AddLiabilitiesFieldsToAccounts < ActiveRecord::Migration[8.0]
  def up
    # Add liability fields to accounts table
    add_column :accounts, :apr_percentage, :decimal, precision: 15, scale: 8
    add_column :accounts, :min_payment_amount, :decimal, precision: 15, scale: 8
    add_column :accounts, :next_payment_due_date, :date
    add_column :accounts, :is_overdue, :boolean
    add_column :accounts, :debt_risk_flag, :boolean
    
    # Add index on is_overdue for query performance
    add_index :accounts, :is_overdue
    
    # Migrate data from liabilities table to accounts
    # Match liability fields: apr_percentage, min_payment_due -> min_payment_amount, payment_due_date -> next_payment_due_date
    execute <<-SQL
      UPDATE accounts
      SET 
        apr_percentage = liabilities.apr_percentage,
        min_payment_amount = liabilities.min_payment_due,
        next_payment_due_date = liabilities.payment_due_date
      FROM liabilities
      WHERE accounts.id = liabilities.account_id
    SQL
    
    # Drop the liabilities table
    drop_table :liabilities
  end
  
  def down
    # Recreate liabilities table
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
    
    # Migrate data back from accounts to liabilities
    # Note: This won't restore liability_id, liability_type, current_balance - data loss on rollback
    execute <<-SQL
      INSERT INTO liabilities (account_id, liability_id, apr_percentage, min_payment_due, payment_due_date, created_at, updated_at)
      SELECT 
        id,
        account_id,
        apr_percentage,
        min_payment_amount,
        next_payment_due_date,
        NOW(),
        NOW()
      FROM accounts
      WHERE apr_percentage IS NOT NULL OR min_payment_amount IS NOT NULL OR next_payment_due_date IS NOT NULL
    SQL
    
    # Remove columns from accounts
    remove_index :accounts, :is_overdue
    remove_column :accounts, :debt_risk_flag
    remove_column :accounts, :is_overdue
    remove_column :accounts, :next_payment_due_date
    remove_column :accounts, :min_payment_amount
    remove_column :accounts, :apr_percentage
  end
end
