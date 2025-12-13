class CreateFixedIncomes < ActiveRecord::Migration[8.0]
  def change
    create_table :fixed_incomes do |t|
      t.references :holding, null: false, foreign_key: true, index: { unique: true }
      t.decimal :yield_percentage, precision: 15, scale: 8
      t.string :yield_type
      t.date :maturity_date
      t.date :issue_date
      t.decimal :face_value, precision: 15, scale: 8
      t.boolean :income_risk_flag, default: false

      t.timestamps
    end
  end
end
