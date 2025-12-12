# app/models/api_cost_log.rb
class ApiCostLog < ApplicationRecord
  validates :api_product, presence: true
  
  # PRD 7.7: Calculate cost for transactions enrich
  # Plaid charges $2.00 per 1,000 transactions
  COST_PER_1000_TRANSACTIONS = 200 # in cents
  
  def self.log_transaction_sync(request_id, transaction_count)
    cost = (transaction_count / 1000.0 * COST_PER_1000_TRANSACTIONS).ceil
    create!(
      api_product: "transactions",
      request_id: request_id,
      transaction_count: transaction_count,
      cost_cents: cost
    )
  end
  
  # Get total cost for a given month
  def self.monthly_total(year, month)
    where("EXTRACT(YEAR FROM created_at) = ? AND EXTRACT(MONTH FROM created_at) = ?", year, month)
      .sum(:cost_cents)
  end
  
  # Get breakdown by product for a given month
  def self.monthly_breakdown(year, month)
    where("EXTRACT(YEAR FROM created_at) = ? AND EXTRACT(MONTH FROM created_at) = ?", year, month)
      .group(:api_product)
      .sum(:cost_cents)
  end
  
  # Format cost in dollars
  def cost_dollars
    "$#{format('%.2f', cost_cents / 100.0)}"
  end
end
