class Holding < ApplicationRecord
  belongs_to :account

  validates :security_id, presence: true
  validates :security_id, uniqueness: { scope: :account_id }
end