class CreateSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.jsonb :data

      t.timestamps
    end
  end
end
