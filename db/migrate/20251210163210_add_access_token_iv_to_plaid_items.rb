class AddAccessTokenIvToPlaidItems < ActiveRecord::Migration[8.0]
  def change
    add_column :plaid_items, :access_token_encrypted_iv, :text
  end
end
