require "test_helper"

class ApiCostLogTest < ActiveSupport::TestCase
  test "creates cost log with valid data" do
    log = ApiCostLog.create!(
      api_product: "transactions",
      request_id: "test_req_123",
      transaction_count: 100,
      cost_cents: 20
    )
    
    assert log.persisted?
    assert_equal "transactions", log.api_product
    assert_equal 100, log.transaction_count
    assert_equal 20, log.cost_cents
  end

  test "requires api_product" do
    log = ApiCostLog.new(
      request_id: "test_req_123",
      transaction_count: 100,
      cost_cents: 20
    )
    
    assert_not log.valid?
    assert_includes log.errors[:api_product], "can't be blank"
  end

  test "log_transaction_sync creates log with correct cost calculation" do
    log = ApiCostLog.log_transaction_sync("req_123", 100)
    
    assert_equal "transactions", log.api_product
    assert_equal "req_123", log.request_id
    assert_equal 100, log.transaction_count
    assert_equal 20, log.cost_cents # $2.00 per 1,000 txns = $0.20 for 100
  end

  test "log_transaction_sync calculates cost for 1000 transactions" do
    log = ApiCostLog.log_transaction_sync("req_456", 1000)
    
    assert_equal 1000, log.transaction_count
    assert_equal 200, log.cost_cents # $2.00 per 1,000 txns
  end

  test "log_transaction_sync rounds up cost for fractional amounts" do
    log = ApiCostLog.log_transaction_sync("req_789", 1500)
    
    assert_equal 1500, log.transaction_count
    assert_equal 300, log.cost_cents # $3.00 for 1,500 txns
  end

  test "monthly_total calculates sum for given month" do
    # Create logs in different months
    ApiCostLog.create!(api_product: "transactions", cost_cents: 100, created_at: Date.new(2025, 12, 1))
    ApiCostLog.create!(api_product: "transactions", cost_cents: 200, created_at: Date.new(2025, 12, 15))
    ApiCostLog.create!(api_product: "transactions", cost_cents: 50, created_at: Date.new(2025, 11, 1))
    
    total = ApiCostLog.monthly_total(2025, 12)
    assert_equal 300, total
  end

  test "monthly_breakdown groups by product" do
    # Create logs for different products
    ApiCostLog.create!(api_product: "transactions", cost_cents: 100, created_at: Date.new(2025, 12, 1))
    ApiCostLog.create!(api_product: "transactions", cost_cents: 200, created_at: Date.new(2025, 12, 15))
    ApiCostLog.create!(api_product: "holdings", cost_cents: 50, created_at: Date.new(2025, 12, 10))
    
    breakdown = ApiCostLog.monthly_breakdown(2025, 12)
    assert_equal 300, breakdown["transactions"]
    assert_equal 50, breakdown["holdings"]
  end

  test "cost_dollars formats cost as currency string" do
    log = ApiCostLog.new(cost_cents: 250)
    assert_equal "$2.50", log.cost_dollars
  end

  test "cost_dollars handles zero cost" do
    log = ApiCostLog.new(cost_cents: 0)
    assert_equal "$0.00", log.cost_dollars
  end

  test "cost_dollars handles large amounts" do
    log = ApiCostLog.new(cost_cents: 123456)
    assert_equal "$1234.56", log.cost_dollars
  end
end
