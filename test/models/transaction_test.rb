require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  # PRD 11: Test investment-specific fields
  test "should save transaction with investment fields" do
    user = User.create!(email: "investor@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test-item-inv",
      institution_name: "Test Brokerage",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-inv-account",
      name: "Investment Account",
      type: "investment", mask: "0000"
    )
    
    transaction = Transaction.new(
      account: account,
      transaction_id: "inv-txn-123",
      name: "Buy AAPL",
      amount: 1500.00,
      date: Date.today,
      fees: 9.99,
      subtype: "buy",
      price: 150.00,
      wash_sale_risk_flag: false
    )
    
    assert transaction.save
    assert_equal BigDecimal("9.99"), transaction.fees
    assert_equal "buy", transaction.subtype
    assert_equal BigDecimal("150.00"), transaction.price
    assert_equal false, transaction.wash_sale_risk_flag
  end
  
  test "should allow nil values for investment fields" do
    user = User.create!(email: "investor2@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test-item-inv2",
      institution_name: "Test Brokerage",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-inv-account-2",
      name: "Investment Account 2",
      type: "investment", mask: "0000"
    )
    
    transaction = Transaction.new(
      account: account,
      transaction_id: "inv-txn-456",
      name: "Dividend",
      amount: 50.00,
      date: Date.today
    )
    
    assert transaction.save, "Should allow nil investment fields for Plaid data gaps"
    assert_nil transaction.fees
    assert_nil transaction.subtype
    assert_nil transaction.price
    assert_nil transaction.dividend_type
    assert_equal false, transaction.wash_sale_risk_flag # default
  end
  
  test "should store dividend_type for dividend transactions" do
    user = User.create!(email: "dividend@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test-item-div",
      institution_name: "Test Brokerage",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-div-account",
      name: "Dividend Account",
      type: "investment", mask: "0000"
    )
    
    transaction = Transaction.create!(
      account: account,
      transaction_id: "div-txn-789",
      name: "MSFT Dividend",
      amount: 125.50,
      date: Date.today,
      subtype: "qualified dividend",
      dividend_type: :qualified
    )
    
    assert_equal "qualified", transaction.dividend_type
    assert_equal "qualified dividend", transaction.subtype
  end
  
  test "should default wash_sale_risk_flag to false" do
    user = User.create!(email: "seller@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test-item-sell",
      institution_name: "Test Brokerage",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-sell-account",
      name: "Sell Account",
      type: "investment", mask: "0000"
    )
    
    transaction = Transaction.create!(
      account: account,
      transaction_id: "sell-txn-111",
      name: "Sell TSLA",
      amount: -2000.00,
      date: Date.today,
      subtype: "sell",
      price: 200.00
    )
    
    assert_equal false, transaction.wash_sale_risk_flag
  end
  
  test "should store decimal values with precision 15 scale 8" do
    user = User.create!(email: "precise@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test-item-prec",
      institution_name: "Test Brokerage",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-prec-account",
      name: "Precise Account",
      type: "investment", mask: "0000"
    )
    
    transaction = Transaction.create!(
      account: account,
      transaction_id: "prec-txn-222",
      name: "Buy Fractional Share",
      amount: 100.1234,
      date: Date.today,
      fees: 1.23,
      price: 99.876543
    )
    
    assert_equal BigDecimal("1.23"), transaction.fees
    assert_equal BigDecimal("99.876543"), transaction.price
  end
end
