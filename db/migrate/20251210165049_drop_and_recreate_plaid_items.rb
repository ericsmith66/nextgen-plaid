class DropAndRecreatePlaidItems < ActiveRecord::Migration[8.0]
  def change
    drop_table :plaid_items, force: :cascade

    create_table :plaid_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :item_id, null: false
      t.string :institution_name
      t.text :access_token_encrypted      # ← encrypted token
      t.text :access_token_encrypted_iv   # ← NEW: per-record random IV
      t.string :status, default: "good"

      t.timestamps
    end

    add_index :plaid_items, [:user_id, :item_id], unique: true
  end
end
