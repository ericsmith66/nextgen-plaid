class ChangeTransactionsSourceToString < ActiveRecord::Migration[8.0]
  def up
    # Convert integer enum (0=plaid, 1=csv) to string enum ("plaid", "manual")
    execute <<~SQL
      ALTER TABLE transactions
      ALTER COLUMN source DROP DEFAULT;
    SQL

    change_column :transactions, :source, :string, using: <<~SQL
      CASE source
        WHEN 0 THEN 'plaid'
        WHEN 1 THEN 'manual'
        ELSE 'manual'
      END
    SQL

    change_column_default :transactions, :source, from: nil, to: "manual"
    change_column_null :transactions, :source, false
  end

  def down
    # Revert back to integer enum (0=plaid default, 1=csv)
    execute <<~SQL
      ALTER TABLE transactions
      ALTER COLUMN source DROP DEFAULT;
    SQL

    change_column :transactions, :source, :integer, using: <<~SQL
      CASE source
        WHEN 'plaid' THEN 0
        WHEN 'manual' THEN 1
        ELSE 0
      END
    SQL

    change_column_default :transactions, :source, from: nil, to: 0
    change_column_null :transactions, :source, false
  end
end
