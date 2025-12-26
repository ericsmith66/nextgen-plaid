require "test_helper"
require "ostruct"

class SyncTransactionsJobTest < ActiveJob::TestCase
  # PRD 11: Test investment transactions sync
  test "sync creates investment transactions with investment fields" do
    user = User.create!(email: "invtxn@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_invtxn", institution_name: "Schwab", access_token: "tok_inv", status: "good")
    
    account = Account.create!(
      plaid_item: item,
      account_id: "acc_inv",
      name: "Investment Account",
      type: "investment",
      subtype: "brokerage",
      mask: "0000"
    )

    fake_sync_response = OpenStruct.new(
      added: [],
      modified: [],
      removed: [],
      has_more: false,
      next_cursor: "new_cursor",
      request_id: "req_sync"
    )

    # Mock regular transactions response (empty for this test)
    fake_transactions_response = OpenStruct.new(
      transactions: [],
      request_id: "req_txn"
    )

    # Mock investment transactions response
    inv_transaction = OpenStruct.new(
      investment_transaction_id: "inv_txn_1",
      account_id: "acc_inv",
      security_id: "sec_aapl",
      name: "Buy AAPL",
      amount: -1500.00,
      date: Date.today,
      iso_currency_code: "USD",
      fees: 9.99,
      subtype: "buy",
      price: 150.00
    )
    
    security = OpenStruct.new(
      security_id: "sec_aapl",
      ticker_symbol: "AAPL",
      name: "Apple Inc."
    )
    
    fake_inv_transactions_response = OpenStruct.new(
      investment_transactions: [inv_transaction],
      securities: [security],
      request_id: "req_inv_txn"
    )

    # Mock recurring transactions response (empty)
    fake_recurring_response = OpenStruct.new(
      inflow_streams: [],
      outflow_streams: []
    )

    with_stubbed_plaid_client(
      transactions_sync: fake_sync_response,
      transactions_get: fake_transactions_response,
      investments_transactions_get: fake_inv_transactions_response,
      transactions_recurring_get: fake_recurring_response
    ) do
      SyncTransactionsJob.perform_now(item.id)
    end

    transaction = Transaction.find_by(transaction_id: "inv_txn_1")
    refute_nil transaction
    assert_equal "Buy AAPL", transaction.name
    assert_equal BigDecimal("-1500.00"), transaction.amount
    assert_equal BigDecimal("9.99"), transaction.fees
    assert_equal "buy", transaction.subtype
    assert_equal BigDecimal("150.00"), transaction.price
    assert_equal false, transaction.wash_sale_risk_flag
    assert_nil transaction.dividend_type
  end

  # PRD 11: Test dividend transaction with dividend_type
  test "sync sets dividend_type for dividend transactions" do
    user = User.create!(email: "divtxn@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_divtxn", institution_name: "JPM", access_token: "tok_div", status: "good")
    
    account = Account.create!(
      plaid_item: item,
      account_id: "acc_div",
      name: "Dividend Account",
      type: "investment",
      subtype: "brokerage",
      mask: "1111"
    )

    fake_transactions_response = OpenStruct.new(transactions: [], request_id: "req_txn")

    inv_transaction = OpenStruct.new(
      investment_transaction_id: "div_txn_1",
      account_id: "acc_div",
      security_id: "sec_msft",
      name: "MSFT Dividend",
      amount: 125.50,
      date: Date.today,
      iso_currency_code: "USD",
      fees: nil,
      subtype: "qualified dividend",
      price: nil
    )
    
    security = OpenStruct.new(security_id: "sec_msft", ticker_symbol: "MSFT", name: "Microsoft")
    
    fake_inv_transactions_response = OpenStruct.new(
      investment_transactions: [inv_transaction],
      securities: [security],
      request_id: "req_div"
    )

    fake_sync_response = OpenStruct.new(
      added: [],
      modified: [],
      removed: [],
      has_more: false,
      next_cursor: "new_cursor",
      request_id: "req_sync"
    )

    fake_recurring_response = OpenStruct.new(inflow_streams: [], outflow_streams: [])

    with_stubbed_plaid_client(
      transactions_sync: fake_sync_response,
      transactions_get: fake_transactions_response,
      investments_transactions_get: fake_inv_transactions_response,
      transactions_recurring_get: fake_recurring_response
    ) do
      SyncTransactionsJob.perform_now(item.id)
    end

    transaction = Transaction.find_by(transaction_id: "div_txn_1")
    refute_nil transaction
    assert_equal "qualified dividend", transaction.subtype
    assert_equal "qualified", transaction.dividend_type
  end

  # PRD 11: Test wash sale detection logic
  test "compute wash sale flag when sell and buy within 30 days" do
    user = User.create!(email: "wash@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_wash", institution_name: "Fidelity", access_token: "tok_wash", status: "good")
    
    account = Account.create!(
      plaid_item: item,
      account_id: "acc_wash",
      name: "Trading Account",
      type: "investment",
      subtype: "brokerage",
      mask: "2222"
    )

    # Create a holding for the security to enable wash sale detection
    holding = Holding.create!(
      account: account,
      security_id: "sec_tesla",
      symbol: "TSLA",
      name: "Tesla Inc.",
      quantity: 10.0,
      cost_basis: 2000.0,
      market_value: 1800.0
    )

    # Create a buy transaction 15 days ago
    buy_date = Date.today - 15.days
    buy_transaction = Transaction.create!(
      account: account,
      transaction_id: "buy_txn_1",
      name: "Buy TSLA",
      amount: -2000.00,
      date: buy_date,
      subtype: "buy",
      price: 200.00
    )

    fake_transactions_response = OpenStruct.new(transactions: [], request_id: "req_txn")

    # Now create a sell transaction
    sell_transaction_data = OpenStruct.new(
      investment_transaction_id: "sell_txn_1",
      account_id: "acc_wash",
      security_id: "sec_tesla",
      name: "Sell TSLA",
      amount: 1800.00,
      date: Date.today,
      iso_currency_code: "USD",
      fees: 9.99,
      subtype: "sell",
      price: 180.00
    )
    
    security = OpenStruct.new(security_id: "sec_tesla", ticker_symbol: "TSLA", name: "Tesla Inc.")
    
    fake_inv_transactions_response = OpenStruct.new(
      investment_transactions: [sell_transaction_data],
      securities: [security],
      request_id: "req_sell"
    )

    fake_sync_response = OpenStruct.new(
      added: [],
      modified: [],
      removed: [],
      has_more: false,
      next_cursor: "new_cursor",
      request_id: "req_sync"
    )

    fake_recurring_response = OpenStruct.new(inflow_streams: [], outflow_streams: [])

    with_stubbed_plaid_client(
      transactions_sync: fake_sync_response,
      transactions_get: fake_transactions_response,
      investments_transactions_get: fake_inv_transactions_response,
      transactions_recurring_get: fake_recurring_response
    ) do
      SyncTransactionsJob.perform_now(item.id)
    end

    sell_transaction = Transaction.find_by(transaction_id: "sell_txn_1")
    refute_nil sell_transaction
    assert_equal "sell", sell_transaction.subtype
    # Wash sale flag should be true because buy exists within 30 days
    assert_equal true, sell_transaction.wash_sale_risk_flag
  end

  # PRD 11: Test no wash sale when no buy within 30 days
  test "does not set wash sale flag when no buy within 30 days" do
    user = User.create!(email: "nowash@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_nowash", institution_name: "Vanguard", access_token: "tok_nowash", status: "good")
    
    account = Account.create!(
      plaid_item: item,
      account_id: "acc_nowash",
      name: "Clean Account",
      type: "investment",
      subtype: "brokerage",
      mask: "3333"
    )

    holding = Holding.create!(
      account: account,
      security_id: "sec_amzn",
      symbol: "AMZN",
      name: "Amazon",
      quantity: 5.0,
      cost_basis: 1000.0,
      market_value: 1100.0
    )

    # Buy was 60 days ago (outside 30-day window)
    buy_date = Date.today - 60.days
    buy_transaction = Transaction.create!(
      account: account,
      transaction_id: "old_buy_1",
      name: "Buy AMZN",
      amount: -1000.00,
      date: buy_date,
      subtype: "buy",
      price: 200.00
    )

    fake_transactions_response = OpenStruct.new(transactions: [], request_id: "req_txn")

    sell_transaction_data = OpenStruct.new(
      investment_transaction_id: "clean_sell_1",
      account_id: "acc_nowash",
      security_id: "sec_amzn",
      name: "Sell AMZN",
      amount: 1100.00,
      date: Date.today,
      iso_currency_code: "USD",
      fees: 9.99,
      subtype: "sell",
      price: 220.00
    )
    
    security = OpenStruct.new(security_id: "sec_amzn", ticker_symbol: "AMZN", name: "Amazon")
    
    fake_inv_transactions_response = OpenStruct.new(
      investment_transactions: [sell_transaction_data],
      securities: [security],
      request_id: "req_clean"
    )

    fake_sync_response = OpenStruct.new(
      added: [],
      modified: [],
      removed: [],
      has_more: false,
      next_cursor: "new_cursor",
      request_id: "req_sync"
    )

    fake_recurring_response = OpenStruct.new(inflow_streams: [], outflow_streams: [])

    with_stubbed_plaid_client(
      transactions_sync: fake_sync_response,
      transactions_get: fake_transactions_response,
      investments_transactions_get: fake_inv_transactions_response,
      transactions_recurring_get: fake_recurring_response
    ) do
      SyncTransactionsJob.perform_now(item.id)
    end

    sell_transaction = Transaction.find_by(transaction_id: "clean_sell_1")
    refute_nil sell_transaction
    assert_equal "sell", sell_transaction.subtype
    # Wash sale flag should remain false
    assert_equal false, sell_transaction.wash_sale_risk_flag
  end

  # PRD 11: Test handling of nil investment fields
  test "handles nil investment transaction fields gracefully" do
    user = User.create!(email: "nilfields@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_nil", institution_name: "ETrade", access_token: "tok_nil", status: "good")
    
    account = Account.create!(
      plaid_item: item,
      account_id: "acc_nil",
      name: "Partial Data Account",
      type: "investment",
      subtype: "brokerage",
      mask: "4444"
    )

    fake_transactions_response = OpenStruct.new(transactions: [], request_id: "req_txn")

    # Investment transaction with nil fees and price
    inv_transaction = OpenStruct.new(
      investment_transaction_id: "nil_txn_1",
      account_id: "acc_nil",
      security_id: "sec_partial",
      name: "Transfer",
      amount: 0.00,
      date: Date.today,
      iso_currency_code: "USD",
      fees: nil,
      subtype: "transfer",
      price: nil
    )
    
    security = OpenStruct.new(security_id: "sec_partial", ticker_symbol: "PART", name: "Partial Security")
    
    fake_inv_transactions_response = OpenStruct.new(
      investment_transactions: [inv_transaction],
      securities: [security],
      request_id: "req_nil"
    )

    fake_sync_response = OpenStruct.new(
      added: [],
      modified: [],
      removed: [],
      has_more: false,
      next_cursor: "new_cursor",
      request_id: "req_sync"
    )

    fake_recurring_response = OpenStruct.new(inflow_streams: [], outflow_streams: [])

    with_stubbed_plaid_client(
      transactions_sync: fake_sync_response,
      transactions_get: fake_transactions_response,
      investments_transactions_get: fake_inv_transactions_response,
      transactions_recurring_get: fake_recurring_response
    ) do
      SyncTransactionsJob.perform_now(item.id)
    end

    transaction = Transaction.find_by(transaction_id: "nil_txn_1")
    refute_nil transaction
    assert_nil transaction.fees
    assert_nil transaction.price
    assert_equal "transfer", transaction.subtype
    assert_equal false, transaction.wash_sale_risk_flag
  end

  test "sync_recurring saves all fields to RecurringTransaction" do
    user = User.create!(email: "recurring@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_recurring", institution_name: "Bank", access_token: "tok_rec", status: "good")
    
    stream = OpenStruct.new(
      stream_id: "stream_1",
      category: ["Food and Drink", "Coffee Shop"],
      description: "Starbucks Recurring",
      merchant_name: "Starbucks",
      frequency: "weekly",
      last_amount: OpenStruct.new(amount: 5.50),
      last_date: Date.today,
      status: "active"
    )

    fake_recurring_response = OpenStruct.new(
      inflow_streams: [],
      outflow_streams: [stream],
      request_id: "req_rec"
    )

    fake_sync_response = OpenStruct.new(added: [], modified: [], removed: [], has_more: false, next_cursor: "c", request_id: "s")
    fake_transactions_response = OpenStruct.new(transactions: [], request_id: "t")
    fake_inv_transactions_response = OpenStruct.new(investment_transactions: [], securities: [], request_id: "i")

    with_stubbed_plaid_client(
      transactions_sync: fake_sync_response,
      transactions_get: fake_transactions_response,
      investments_transactions_get: fake_inv_transactions_response,
      transactions_recurring_get: fake_recurring_response
    ) do
      SyncTransactionsJob.perform_now(item.id)
    end

    recurring = RecurringTransaction.find_by(stream_id: "stream_1")
    refute_nil recurring
    assert_equal "Food and Drink, Coffee Shop", recurring.category
    assert_equal "Starbucks Recurring", recurring.description
    assert_equal "Starbucks", recurring.merchant_name
    assert_equal "weekly", recurring.frequency
    assert_equal BigDecimal("5.50"), recurring.last_amount
    assert_equal Date.today, recurring.last_date
    assert_equal "active", recurring.status
  end
end
