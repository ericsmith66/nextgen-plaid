class Account < ApplicationRecord
  belongs_to :plaid_item
  has_many :holdings, dependent: :destroy
  has_many :transactions, dependent: :destroy

  # THIS LINE DISABLES STI — type column is just data
  self.inheritance_column = :_type_disabled

  # CSV-3: Source enum for tracking data origin
  attribute :source, :integer, default: 0
  enum :source, { plaid: 0, csv: 1 }

  validates :account_id, presence: true
  validates :mask, presence: true
  # PRD 5: Uniqueness handled by DB unique index [plaid_item_id, account_id]
  # validates :account_id, uniqueness: { scope: [ :plaid_item_id, :source ] }

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

  # PRD 12: HNW Hook - Check if account has overdue payments (for "Owner" level tax simulations)
  # Used in curriculum for trust/generational transfer penalty impacts
  def overdue_payment?
    is_overdue == true
  end

  # PRD 12: HNW Hook - Check if account has high debt risk (APR > 5% or overdue)
  # Used in "Investor" and "Principal" levels for debt cost analysis in family LLCs
  def high_debt_risk?
    debt_risk_flag == true
  end

  # PRD 12: HNW Hook - Get liability summary for curriculum (debt prioritization simulations)
  def liability_summary
    return nil unless apr_percentage.present? || min_payment_amount.present?
    
    {
      apr_percentage: apr_percentage,
      min_payment_amount: min_payment_amount,
      next_payment_due_date: next_payment_due_date,
      is_overdue: is_overdue,
      debt_risk_flag: debt_risk_flag
    }
  end
end
