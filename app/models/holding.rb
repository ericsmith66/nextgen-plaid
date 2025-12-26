class Holding < ApplicationRecord
  belongs_to :account
  has_one :fixed_income, dependent: :destroy
  has_one :option_contract, dependent: :destroy

  # PRD 10: Disable STI — type column is for security type data, not inheritance
  self.inheritance_column = :_type_disabled

  # CSV-2: Source enum for tracking data origin
  attribute :source, :integer, default: 0
  enum :source, { plaid: 0, csv: 1 }

  validates :security_id, presence: true
  # PRD 8: Uniqueness handled by DB unique index [account_id, security_id, source]
  # validates :security_id, uniqueness: { scope: [ :account_id, :source ] }
  
  # CSV-2: Validations for CSV imports
  validates :symbol, presence: true, if: :csv?
  validates :quantity, presence: true, if: :csv?
  validates :market_value, presence: true, if: :csv?

  # Decimal fields that require fixed notation formatting
  DECIMAL_FIELDS = %w[quantity cost_basis market_value vested_value institution_price].freeze

  # Formatting methods for decimal fields to avoid scientific notation
  def quantity_s
    quantity&.to_s('F')
  end

  def cost_basis_s
    cost_basis&.to_s('F')
  end

  def market_value_s
    market_value&.to_s('F')
  end

  def vested_value_s
    vested_value&.to_s('F')
  end

  def institution_price_s
    institution_price&.to_s('F')
  end

  # Override inspect to show fixed decimal notation in console
  def inspect
    attrs = attributes.map do |k, v|
      if DECIMAL_FIELDS.include?(k) && v.is_a?(BigDecimal)
        "#{k}: #{v.to_s('F')}"
      else
        "#{k}: #{v.inspect}"
      end
    end.join(", ")
    "#<Holding #{attrs}>"
  end
end