require "test_helper"

class PlaidItemTest < ActiveSupport::TestCase
  test "dependent destroy cascades to accounts" do
    user = User.create!(email: "test@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test_item_123",
      institution_name: "Test Bank",
      access_token: "test_token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test_account_123",
      name: "Test Account",
      type: "investment",
      subtype: "brokerage"
    )
    
    account_id = account.id
    
    assert_difference "Account.count", -1 do
      plaid_item.destroy!
    end
    
    assert_nil Account.find_by(id: account_id)
  end
  
  test "dependent destroy cascades to holdings through accounts" do
    user = User.create!(email: "test2@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test_item_456",
      institution_name: "Test Bank",
      access_token: "test_token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test_account_456",
      name: "Test Account",
      type: "investment",
      subtype: "brokerage"
    )
    
    holding = Holding.create!(
      account: account,
      security_id: "sec_aapl_123",
      symbol: "AAPL",
      name: "Apple Inc.",
      quantity: 10.0,
      market_value: 1500.00
    )
    
    holding_id = holding.id
    
    assert_difference "Holding.count", -1 do
      plaid_item.destroy!
    end
    
    assert_nil Holding.find_by(id: holding_id)
  end
  
  test "dependent destroy cascades to transactions through accounts" do
    user = User.create!(email: "test3@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test_item_789",
      institution_name: "Test Bank",
      access_token: "test_token",
      status: "good"
    )
    
    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "test_account_789",
      name: "Test Account",
      type: "depository",
      subtype: "checking"
    )
    
    transaction = Transaction.create!(
      account: account,
      transaction_id: "test_txn_123",
      amount: 50.00,
      date: Date.today,
      name: "Test Transaction"
    )
    
    transaction_id = transaction.id
    
    assert_difference "Transaction.count", -1 do
      plaid_item.destroy!
    end
    
    assert_nil Transaction.find_by(id: transaction_id)
  end
  
  test "dependent destroy cascades to recurring_transactions" do
    user = User.create!(email: "test4@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test_item_recurring",
      institution_name: "Test Bank",
      access_token: "test_token",
      status: "good"
    )
    
    recurring_transaction = RecurringTransaction.create!(
      plaid_item: plaid_item,
      stream_id: "test_stream_123",
      description: "Monthly Subscription",
      frequency: "MONTHLY",
      average_amount: 9.99
    )
    
    recurring_transaction_id = recurring_transaction.id
    
    assert_difference "RecurringTransaction.count", -1 do
      plaid_item.destroy!
    end
    
    assert_nil RecurringTransaction.find_by(id: recurring_transaction_id)
  end
  
  test "dependent destroy cascades to sync_logs" do
    user = User.create!(email: "test5@example.com", password: "Password!123")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "test_item_logs",
      institution_name: "Test Bank",
      access_token: "test_token",
      status: "good"
    )
    
    sync_log = SyncLog.create!(
      plaid_item: plaid_item,
      job_type: "holdings",
      status: "success"
    )
    
    sync_log_id = sync_log.id
    
    assert_difference "SyncLog.count", -1 do
      plaid_item.destroy!
    end
    
    assert_nil SyncLog.find_by(id: sync_log_id)
  end
end
