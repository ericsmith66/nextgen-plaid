# app/models/plaid_api_call.rb
class PlaidApiCall < ApplicationRecord
  validates :product, presence: true
  validates :endpoint, presence: true
  
  # PRD 8.1: Load costs from YAML config
  def self.costs
    @costs ||= YAML.load_file(Rails.root.join('config', 'plaid_costs.yml'))
  end
  
  # PRD 8.2: Log API call with endpoint and cost from YAML
  def self.log_call(product:, endpoint:, request_id: nil, count: 0)
    cost = calculate_cost(product, endpoint, count)
    create!(
      product: product,
      endpoint: endpoint,
      request_id: request_id,
      transaction_count: count,
      cost_cents: cost,
      called_at: Time.current
    )
  end
  
  # Calculate cost based on YAML config
  def self.calculate_cost(product, endpoint, count = 0)
    costs_config = costs
    
    # Check volume-based costs (e.g., enrich)
    if endpoint.include?('enrich') || product == 'enrich'
      cost_per_txn = costs_config.dig('volume', 'enrich_per_transaction') || 0.2
      return (count * cost_per_txn).ceil
    end
    
    # Check per-call costs
    per_call_cost = costs_config.dig('per_call', endpoint) || 0
    return per_call_cost if per_call_cost > 0
    
    # Check monthly per-item costs (prorated per call)
    monthly_cost = costs_config.dig('monthly_per_item', product) || 0
    return monthly_cost if monthly_cost > 0
    
    # Default: free
    0
  end
  
  # Get total cost for a given month
  def self.monthly_total(year, month)
    where("EXTRACT(YEAR FROM called_at) = ? AND EXTRACT(MONTH FROM called_at) = ?", year, month)
      .sum(:cost_cents)
  end
  
  # Get breakdown by product for a given month
  def self.monthly_breakdown(year, month)
    where("EXTRACT(YEAR FROM called_at) = ? AND EXTRACT(MONTH FROM called_at) = ?", year, month)
      .group(:product)
      .sum(:cost_cents)
  end
  
  # PRD 8.6: Monthly summary grouped by month
  def self.monthly_summary
    select("DATE_TRUNC('month', called_at) as month, SUM(cost_cents) as total_cents, COUNT(*) as call_count")
      .group("DATE_TRUNC('month', called_at)")
      .order("month DESC")
  end
  
  # Format cost in dollars
  def cost_dollars
    "$#{format('%.2f', cost_cents / 100.0)}"
  end
  
  # Average cost per call for a month
  def self.average_per_call(year, month)
    calls = where("EXTRACT(YEAR FROM called_at) = ? AND EXTRACT(MONTH FROM called_at) = ?", year, month)
    total = calls.sum(:cost_cents)
    count = calls.count
    count > 0 ? (total.to_f / count).round(2) : 0
  end
end
