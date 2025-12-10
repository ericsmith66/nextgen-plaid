class CreatePlaidItems < ActiveRecord::Migration[8.0]
  def change
    create_table :plaid_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :item_id
      t.string :institution_name
      t.string :access_token_encrypted
      t.string :status

      t.timestamps
    end
  end
end
