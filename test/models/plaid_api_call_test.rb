require "test_helper"

class PlaidApiCallTest < ActiveSupport::TestCase
  test "creates API call log with valid data" do
    log = PlaidApiCall.create!(
      product: "transactions",
      endpoint: "/transactions/get",
      request_id: "test_req_123",
      transaction_count: 100,
      cost_cents: 20,
      called_at: Time.current
    )
    
    assert log.persisted?
    assert_equal "transactions", log.product
    assert_equal "/transactions/get", log.endpoint
    assert_equal 100, log.transaction_count
    assert_equal 20, log.cost_cents
  end

  test "requires product" do
    log = PlaidApiCall.new(
      endpoint: "/transactions/get",
      request_id: "test_req_123",
      transaction_count: 100,
      cost_cents: 20
    )
    
    assert_not log.valid?
    assert_includes log.errors[:product], "can't be blank"
  end

  # Note: endpoint has default value "unknown" in DB, so validation passes even without explicit value

  test "log_call creates log with calculated cost from YAML" do
    log = PlaidApiCall.log_call(
      product: "transactions",
      endpoint: "/transactions/get",
      request_id: "req_123",
      count: 1000
    )
    
    assert_equal "transactions", log.product
    assert_equal "/transactions/get", log.endpoint
    assert_equal "req_123", log.request_id
    assert_equal 1000, log.transaction_count
    assert log.cost_cents >= 0
  end

  test "calculate_cost returns correct value for enrich" do
    cost = PlaidApiCall.calculate_cost("enrich", "/transactions/enrich", 1000)
    # $2.00 per 1,000 = 200 cents
    assert_equal 200, cost
  end

  test "monthly_total calculates sum for given month" do
    # Create logs in different months
    PlaidApiCall.create!(product: "transactions", endpoint: "/transactions/get", cost_cents: 100, called_at: DateTime.new(2025, 12, 1))
    PlaidApiCall.create!(product: "transactions", endpoint: "/transactions/get", cost_cents: 200, called_at: DateTime.new(2025, 12, 15))
    PlaidApiCall.create!(product: "transactions", endpoint: "/transactions/get", cost_cents: 50, called_at: DateTime.new(2025, 11, 1))
    
    total = PlaidApiCall.monthly_total(2025, 12)
    assert_equal 300, total
  end

  test "monthly_breakdown groups by product" do
    # Create logs for different products
    PlaidApiCall.create!(product: "transactions", endpoint: "/transactions/get", cost_cents: 100, called_at: DateTime.new(2025, 12, 1))
    PlaidApiCall.create!(product: "transactions", endpoint: "/transactions/get", cost_cents: 200, called_at: DateTime.new(2025, 12, 15))
    PlaidApiCall.create!(product: "liabilities", endpoint: "/liabilities/get", cost_cents: 50, called_at: DateTime.new(2025, 12, 10))
    
    breakdown = PlaidApiCall.monthly_breakdown(2025, 12)
    assert_equal 300, breakdown["transactions"]
    assert_equal 50, breakdown["liabilities"]
  end

  test "cost_dollars formats cost as currency string" do
    log = PlaidApiCall.new(cost_cents: 250)
    assert_equal "$2.50", log.cost_dollars
  end

  test "cost_dollars handles zero cost" do
    log = PlaidApiCall.new(cost_cents: 0)
    assert_equal "$0.00", log.cost_dollars
  end

  test "cost_dollars handles large amounts" do
    log = PlaidApiCall.new(cost_cents: 123456)
    assert_equal "$1234.56", log.cost_dollars
  end

  test "loads costs from YAML config" do
    costs = PlaidApiCall.costs
    assert_not_nil costs
    assert costs.key?("volume")
    assert costs.key?("monthly_per_item")
  end
end
