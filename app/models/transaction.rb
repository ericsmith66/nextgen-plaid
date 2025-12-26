class Transaction < ApplicationRecord
  belongs_to :account
  has_one :enriched_transaction, dependent: :destroy

  # Lookup associations (all optional per PRD UC-14)
  belongs_to :merchant, optional: true
  belongs_to :personal_finance_category, optional: true
  belongs_to :transaction_code, optional: true

  # Data origin for transactions
  # string-backed enum
  # values: "plaid", "manual" (default)
  attribute :source, :string
  enum :source, { plaid: "plaid", manual: "manual", csv: "csv" }

  default_scope { where(deleted_at: nil) }

  # CSV imports often do not have a Plaid transaction_id
  # Require transaction_id only for Plaid-sourced rows
  validates :transaction_id, presence: true, if: -> { source == "plaid" }
  # PRD 5: Uniqueness handled by DB unique index [account_id, transaction_id]
  # validates :transaction_id, uniqueness: { scope: :account_id }, allow_nil: true

  # Deduplication for CSV/manual sources (fingerprint computed in importer)
  # validates :dedupe_fingerprint, uniqueness: { scope: :account_id }, allow_nil: true

  # Basic data integrity for imported transactions
  validates :date, presence: true, if: -> { source == "manual" }
  validates :amount, presence: true, if: -> { source == "manual" }

  # Enums (string-backed)
  enum :dividend_type, {
    domestic: "domestic",
    foreign: "foreign",
    qualified: "qualified",
    non_qualified: "non_qualified",
    unknown: "unknown"
  }, prefix: true

  enum :personal_finance_category_confidence_level, {
    very_high: "very_high",
    high: "high",
    medium: "medium",
    low: "low",
    unknown: "unknown"
  }, prefix: true

  # Investments subtype (string-backed). Accept any string, but provide helper scope.
  scope :investment, -> { where.not(subtype: nil) }

  # JSONB size validation: ensure large blobs stay under ~1MB each row (combined)
  validate :jsonb_payload_size_limit

  # Helpful scopes
  scope :for_core_match, ->(account_id:, date:, amount:, description:) {
    where(account_id: account_id, date: date, amount: amount, name: description)
  }

  private

  def jsonb_payload_size_limit
    limit_bytes = 1_000_000
    blobs = [location, payment_meta, counterparties]
    total = blobs.compact.sum { |h| h.to_json.bytesize }
    errors.add(:base, "JSON payload too large (#{total} bytes > #{limit_bytes})") if total > limit_bytes
  end
end
