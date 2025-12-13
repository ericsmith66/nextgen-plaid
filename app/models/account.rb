class Account < ApplicationRecord
  belongs_to :plaid_item
  has_many :holdings, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :liabilities, dependent: :destroy

  # THIS LINE DISABLES STI — type column is just data
  self.inheritance_column = :_type_disabled

  validates :account_id, presence: true
  validates :account_id, uniqueness: { scope: :plaid_item_id }

  # PRD 9: Check if any sector exceeds 30% concentration (diversification risk)
  def diversification_risk?
    return false if holdings.empty?
    
    total_value = holdings.sum { |h| h.market_value.to_f }
    return false if total_value <= 0
    
    sector_values = holdings.group_by(&:sector).transform_values do |sector_holdings|
      sector_holdings.sum { |h| h.market_value.to_f }
    end
    
    sector_values.any? { |sector, value| (value / total_value) > 0.30 }
  end

  # PRD 9: Get sector concentrations as percentages
  def sector_concentrations
    return {} if holdings.empty?
    
    total_value = holdings.sum { |h| h.market_value.to_f }
    return {} if total_value <= 0
    
    holdings.group_by(&:sector).transform_values do |sector_holdings|
      sector_value = sector_holdings.sum { |h| h.market_value.to_f }
      ((sector_value / total_value) * 100).round(2)
    end
  end

  # PRD 9: HNW Hook - Check for Non-Profit sector holdings (DAF/philanthropy curriculum)
  def has_nonprofit_holdings?
    holdings.any? { |h| h.sector&.downcase&.include?("non-profit") || h.sector&.downcase&.include?("nonprofit") }
  end

  # PRD 9: HNW Hook - Get all Non-Profit sector holdings
  def nonprofit_holdings
    holdings.select { |h| h.sector&.downcase&.include?("non-profit") || h.sector&.downcase&.include?("nonprofit") }
  end
end
