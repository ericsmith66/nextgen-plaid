class PersonalFinanceCategory < ApplicationRecord
  has_many :transactions

  validates :primary, presence: true
  validates :detailed, presence: true
  validates :primary, uniqueness: { scope: :detailed }
end
