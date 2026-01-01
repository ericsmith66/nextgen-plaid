class CreateSolidCableMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_cable_messages, if_not_exists: true do |t|
      t.binary :channel, limit: 1024, null: false
      t.binary :payload, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.bigint :channel_hash, null: false

      t.index :channel, if_not_exists: true
      t.index :channel_hash, if_not_exists: true
      t.index :created_at, if_not_exists: true
    end
  end
end
