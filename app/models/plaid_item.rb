# app/models/plaid_item.rb
class PlaidItem < ApplicationRecord
  belongs_to :user
  has_many :accounts, dependent: :destroy
  has_many :positions, through: :accounts

  # This is the correct, final version for 2025
  attr_encrypted :access_token,
                 key: ACCESS_TOKEN_ENCRYPTION_KEY,        # 32-byte binary key from initializer
                 attribute: 'access_token_encrypted',     # write to the column you have
                 random_iv: true                          # use the _iv column we added

  attr_encrypted_encrypted_attributes
end