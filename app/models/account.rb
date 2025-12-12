class Account < ApplicationRecord
  belongs_to :plaid_item
  has_many :holdings, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :liabilities, dependent: :destroy

  # THIS LINE DISABLES STI — type column is just data
  self.inheritance_column = :_type_disabled

  validates :account_id, presence: true
  validates :account_id, uniqueness: { scope: :plaid_item_id }
end
