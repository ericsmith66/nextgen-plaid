class Holding < ApplicationRecord
  belongs_to :account

  validates :security_id, presence: true
  validates :security_id, uniqueness: { scope: :account_id }

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
      if %w[quantity cost_basis market_value vested_value institution_price].include?(k) && v.is_a?(BigDecimal)
        "#{k}: #{v.to_s('F')}"
      else
        "#{k}: #{v.inspect}"
      end
    end.join(", ")
    "#<Holding #{attrs}>"
  end
end