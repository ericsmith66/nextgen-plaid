class CreatePositions < ActiveRecord::Migration[8.0]
  def change
    create_table :positions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :security_id
      t.string :symbol
      t.string :name
      t.decimal :quantity
      t.decimal :cost_basis
      t.decimal :market_value

      t.timestamps
    end
  end
end
