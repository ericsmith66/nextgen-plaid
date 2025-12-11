class Liability < ApplicationRecord
  belongs_to :account

  validates :liability_id, presence: true
  validates :liability_id, uniqueness: { scope: :account_id }
end
