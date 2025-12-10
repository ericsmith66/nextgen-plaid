class Account < ApplicationRecord
  belongs_to :plaid_item
  has_many :positions, dependent: :destroy

  # THIS LINE DISABLES STI — type column is just data
  self.inheritance_column = :_type_disabled
end
