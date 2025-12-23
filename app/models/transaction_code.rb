class TransactionCode < ApplicationRecord
  has_many :transactions

  validates :code, presence: true, uniqueness: true
end
