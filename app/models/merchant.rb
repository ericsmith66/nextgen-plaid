class Merchant < ApplicationRecord
  has_many :transactions

  validates :merchant_entity_id, presence: true, uniqueness: true
end
