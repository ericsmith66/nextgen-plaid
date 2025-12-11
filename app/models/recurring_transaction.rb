class RecurringTransaction < ApplicationRecord
  belongs_to :plaid_item

  validates :stream_id, presence: true
  validates :stream_id, uniqueness: { scope: :plaid_item_id }
end
