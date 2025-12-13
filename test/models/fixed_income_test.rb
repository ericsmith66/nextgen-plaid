require "test_helper"

class FixedIncomeTest < ActiveSupport::TestCase
  test "should belong to holding" do
    user = User.create!(email: "test1@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test-item-1",
      institution_name: "Test Bank",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-account-id",
      name: "Test Account"
    )
    
    holding = Holding.create!(
      account: account,
      security_id: "bond-123",
      symbol: "DBLTX",
      name: "Test Bond"
    )
    
    fixed_income = FixedIncome.new(
      holding: holding,
      yield_percentage: 3.5,
      yield_type: "coupon",
      maturity_date: Date.today + 5.years,
      face_value: 10000
    )
    
    assert fixed_income.save
    assert_equal holding, fixed_income.holding
  end
  
  test "should allow all fields to be nil" do
    user = User.create!(email: "test2@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test-item-2",
      institution_name: "Test Bank",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-account-id",
      name: "Test Account"
    )
    
    holding = Holding.create!(
      account: account,
      security_id: "bond-456",
      symbol: "TEST",
      name: "Test Incomplete Bond"
    )
    
    fixed_income = FixedIncome.new(holding: holding)
    
    assert fixed_income.save, "Should allow nil fields for Plaid data gaps"
    assert_nil fixed_income.yield_percentage
    assert_nil fixed_income.maturity_date
  end
  
  test "should default income_risk_flag to false" do
    user = User.create!(email: "test3@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test-item-3",
      institution_name: "Test Bank",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-account-id",
      name: "Test Account"
    )
    
    holding = Holding.create!(
      account: account,
      security_id: "bond-789",
      symbol: "SAFE",
      name: "Safe Bond"
    )
    
    fixed_income = FixedIncome.create!(holding: holding, yield_percentage: 4.5)
    
    assert_equal false, fixed_income.income_risk_flag
  end
  
  test "should store decimal values with precision 15 scale 8" do
    user = User.create!(email: "test4@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test-item-4",
      institution_name: "Test Bank",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-account-id",
      name: "Test Account"
    )
    
    holding = Holding.create!(
      account: account,
      security_id: "bond-precise",
      symbol: "PREC",
      name: "Precise Bond"
    )
    
    fixed_income = FixedIncome.create!(
      holding: holding,
      yield_percentage: 1.23456789,
      face_value: 9999999.87654321
    )
    
    assert_equal BigDecimal("1.23456789"), fixed_income.yield_percentage
    assert_equal BigDecimal("9999999.87654321"), fixed_income.face_value
  end
end
