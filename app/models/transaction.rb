class Transaction < ApplicationRecord
  belongs_to :account

  validates :transaction_id, presence: true
  validates :transaction_id, uniqueness: { scope: :account_id }
end
