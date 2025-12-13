class CreateOptionContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :option_contracts do |t|
      t.references :holding, null: false, foreign_key: true, index: { unique: true }
      t.string :contract_type
      t.date :expiration_date
      t.decimal :strike_price, precision: 15, scale: 8
      t.string :underlying_ticker

      t.timestamps
    end
  end
end
