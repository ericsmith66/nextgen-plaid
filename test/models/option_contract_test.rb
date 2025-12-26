require "test_helper"

class OptionContractTest < ActiveSupport::TestCase
  test "should belong to holding" do
    user = User.create!(email: "opt1@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "opt-item-1",
      institution_name: "Test Bank",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-account-id",
      name: "Test Account", mask: "0000"
    )
    
    holding = Holding.create!(
      account: account,
      security_id: "option-123",
      symbol: "NFLX",
      name: "Netflix Call Option"
    )
    
    option_contract = OptionContract.new(
      holding: holding,
      contract_type: "call",
      expiration_date: Date.today + 90.days,
      strike_price: 450.00,
      underlying_ticker: "NFLX"
    )
    
    assert option_contract.save
    assert_equal holding, option_contract.holding
  end
  
  test "should allow all fields to be nil" do
    user = User.create!(email: "opt2@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "opt-item-2",
      institution_name: "Test Bank",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-account-id",
      name: "Test Account", mask: "0000"
    )
    
    holding = Holding.create!(
      account: account,
      security_id: "option-456",
      symbol: "TEST",
      name: "Test Incomplete Option"
    )
    
    option_contract = OptionContract.new(holding: holding)
    
    assert option_contract.save, "Should allow nil fields for Plaid data gaps"
    assert_nil option_contract.contract_type
    assert_nil option_contract.expiration_date
    assert_nil option_contract.strike_price
  end
  
  test "should accept put and call contract types" do
    user = User.create!(email: "opt3@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "opt-item-3",
      institution_name: "Test Bank",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-account-id",
      name: "Test Account", mask: "0000"
    )
    
    holding_call = Holding.create!(
      account: account,
      security_id: "option-call",
      symbol: "AAPL",
      name: "Apple Call"
    )
    
    holding_put = Holding.create!(
      account: account,
      security_id: "option-put",
      symbol: "AAPL",
      name: "Apple Put"
    )
    
    call_option = OptionContract.create!(
      holding: holding_call,
      contract_type: "call",
      strike_price: 180.00
    )
    
    put_option = OptionContract.create!(
      holding: holding_put,
      contract_type: "put",
      strike_price: 170.00
    )
    
    assert_equal "call", call_option.contract_type
    assert_equal "put", put_option.contract_type
  end
  
  test "should store strike_price with precision 15 scale 8" do
    user = User.create!(email: "opt4@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "opt-item-4",
      institution_name: "Test Bank",
      access_token: "test-token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test-account-id",
      name: "Test Account", mask: "0000"
    )
    
    holding = Holding.create!(
      account: account,
      security_id: "option-precise",
      symbol: "PREC",
      name: "Precise Option"
    )
    
    option_contract = OptionContract.create!(
      holding: holding,
      strike_price: 123.45678901
    )
    
    assert_equal BigDecimal("123.45678901"), option_contract.strike_price
  end
end
