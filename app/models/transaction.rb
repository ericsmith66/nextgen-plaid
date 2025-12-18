class Transaction < ApplicationRecord
  belongs_to :account
  has_one :enriched_transaction, dependent: :destroy

  # Data origin for transactions
  # string-backed enum
  # values: "plaid", "manual" (default)
  attribute :source, :string
  enum :source, { plaid: "plaid", manual: "manual" }

  # CSV imports often do not have a Plaid transaction_id
  # Require transaction_id only for Plaid-sourced rows
  validates :transaction_id, presence: true, if: -> { source == "plaid" }
  validates :transaction_id, uniqueness: { scope: :account_id }, allow_nil: true

  # Basic data integrity for imported transactions
  validates :date, presence: true, if: -> { source == "manual" }
  validates :amount, presence: true, if: -> { source == "manual" }

  # Helpful scopes
  scope :for_core_match, ->(account_id:, date:, amount:, description:) {
    where(account_id: account_id, date: date, amount: amount, name: description)
  }
end
