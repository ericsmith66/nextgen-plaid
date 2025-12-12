class Transaction < ApplicationRecord
  belongs_to :account
  has_one :enriched_transaction, dependent: :destroy

  validates :transaction_id, presence: true
  validates :transaction_id, uniqueness: { scope: :account_id }
end
