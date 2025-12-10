class ChangeAccessTokenEncryptedToText < ActiveRecord::Migration[8.0]
  def change
    change_column :plaid_items, :access_token_encrypted, :text
  end
end