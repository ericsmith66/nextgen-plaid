require "test_helper"
require "ostruct"

class SyncHoldingsJobTest < ActiveJob::TestCase
  test "sync creates accounts and holdings from Plaid response" do
    user = User.create!(email: "sync@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_1", institution_name: "Test Inst", access_token: "tok_1", status: "good")

    balances = OpenStruct.new(current: 1000.25, iso_currency_code: "USD")
    plaid_account = OpenStruct.new(account_id: "acc_1", name: "Brokerage", mask: "1234", type: "investment", subtype: "brokerage", balances: balances)

    holding = OpenStruct.new(account_id: "acc_1", security_id: "sec_1", quantity: 10.5, cost_basis: 950.0, institution_value: 1050.0, market_value: 1040.0)
    security = OpenStruct.new(security_id: "sec_1", ticker_symbol: "AAPL", name: "Apple Inc.")

    fake_response = OpenStruct.new(accounts: [plaid_account], holdings: [holding], securities: [security])

    with_stubbed_plaid_client(investments_holdings_get: fake_response) do
      perform_enqueued_jobs do
        SyncHoldingsJob.perform_now(item.id)
      end
    end

    item.reload
    assert_equal 1, item.accounts.count
    assert_equal 1, item.holdings.count

    # PRD 5.5: both last_holdings_sync_at and holdings_synced_at should be set on successful sync
    refute_nil item.last_holdings_sync_at
    assert item.last_holdings_sync_at <= Time.now && item.last_holdings_sync_at > Time.now - 60
    refute_nil item.holdings_synced_at
    assert item.holdings_synced_at <= Time.now && item.holdings_synced_at > Time.now - 60

    account = item.accounts.find_by(account_id: "acc_1")
    refute_nil account
    assert_equal "Brokerage", account.name
    assert_equal "investment", account.type
    assert_equal "brokerage", account.subtype
    assert_equal BigDecimal("1000.25"), account.current_balance
    assert_equal "USD", account.iso_currency_code

    pos = account.holdings.find_by(security_id: "sec_1")
    refute_nil pos
    assert_equal "AAPL", pos.symbol
    assert_equal "Apple Inc.", pos.name
    assert_equal BigDecimal("10.5"), pos.quantity
    assert_equal BigDecimal("950.0"), pos.cost_basis
    assert_equal BigDecimal("1050.0"), pos.market_value
  end

  test "creates success and started logs on successful run" do
    user = User.create!(email: "logs@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_log", institution_name: "Inst", access_token: "tok", status: "good")

    balances = OpenStruct.new(current: 1, iso_currency_code: "USD")
    plaid_account = OpenStruct.new(account_id: "acc_x", name: "A", mask: "1", type: "investment", subtype: "brokerage", balances: balances)
    holding = OpenStruct.new(account_id: "acc_x", security_id: "sec_x", quantity: 1, cost_basis: 1, institution_value: 1, market_value: 1)
    security = OpenStruct.new(security_id: "sec_x", ticker_symbol: "TCK", name: "Sec")
    fake_response = OpenStruct.new(accounts: [plaid_account], holdings: [holding], securities: [security])

    with_stubbed_plaid_client(investments_holdings_get: fake_response) do
      assert_difference 'SyncLog.where(plaid_item: item, job_type: "holdings", status: "started").count', +1 do
        assert_difference 'SyncLog.where(plaid_item: item, job_type: "holdings", status: "success").count', +1 do
          SyncHoldingsJob.perform_now(item.id)
        end
      end
    end
  end

  test "creates failure log when an error occurs" do
    user = User.create!(email: "logs2@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_fail", institution_name: "Inst", access_token: "tok", status: "good")

    # Stub client to raise a generic error (captured by job)
    stub = Minitest::Mock.new
    def stub.investments_holdings_get(_req); raise StandardError, "boom"; end
    original = Rails.application.config.x.plaid_client
    Rails.application.config.x.plaid_client = stub

    assert_raises(StandardError) do
      SyncHoldingsJob.perform_now(item.id)
    end

    Rails.application.config.x.plaid_client = original

    failure = SyncLog.where(plaid_item: item, job_type: "holdings", status: "failure").order(created_at: :desc).first
    refute_nil failure
    assert_includes failure.error_message, "boom"
  end

  # PRD 8: Test extended fields mapping
  test "sync maps extended fields from Plaid response" do
    user = User.create!(email: "extended@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_ext", institution_name: "JPM", access_token: "tok_ext", status: "good")

    balances = OpenStruct.new(current: 5000.0, iso_currency_code: "USD")
    plaid_account = OpenStruct.new(account_id: "acc_ext", name: "Investment", mask: "5678", type: "investment", subtype: "brokerage", balances: balances)

    # Mock holding with extended fields
    holding = OpenStruct.new(
      account_id: "acc_ext",
      security_id: "sec_ext",
      quantity: 100.0,
      cost_basis: 5000.0,
      institution_value: 8000.0,
      market_value: 8000.0,
      vested_value: 7500.0,
      institution_price: 80.0,
      institution_price_as_of: "2025-12-13T10:00:00Z"
    )
    security = OpenStruct.new(security_id: "sec_ext", ticker_symbol: "TSLA", name: "Tesla Inc.")

    fake_response = OpenStruct.new(accounts: [plaid_account], holdings: [holding], securities: [security], request_id: "req_ext")

    with_stubbed_plaid_client(investments_holdings_get: fake_response) do
      SyncHoldingsJob.perform_now(item.id)
    end

    pos = item.holdings.find_by(security_id: "sec_ext")
    refute_nil pos
    
    # Check extended fields
    assert_equal BigDecimal("7500.0"), pos.vested_value
    assert_equal BigDecimal("80.0"), pos.institution_price
    assert_equal "2025-12-13T10:00:00Z", pos.institution_price_as_of.iso8601
    
    # Check high_cost_flag: (8000 - 5000) / 5000 = 0.6 > 0.5
    assert pos.high_cost_flag
  end

  # PRD 8: Test high_cost_flag edge cases
  test "high_cost_flag is false when gain is below 50 percent threshold" do
    user = User.create!(email: "lowgain@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_low", institution_name: "Test", access_token: "tok_low", status: "good")

    balances = OpenStruct.new(current: 1000.0, iso_currency_code: "USD")
    plaid_account = OpenStruct.new(account_id: "acc_low", name: "Acct", mask: "1111", type: "investment", subtype: "brokerage", balances: balances)

    # 40% gain: (1400 - 1000) / 1000 = 0.4 < 0.5
    holding = OpenStruct.new(
      account_id: "acc_low",
      security_id: "sec_low",
      quantity: 10.0,
      cost_basis: 1000.0,
      institution_value: 1400.0,
      market_value: 1400.0,
      vested_value: nil,
      institution_price: 140.0,
      institution_price_as_of: nil
    )
    security = OpenStruct.new(security_id: "sec_low", ticker_symbol: "BOND", name: "Bond Fund")

    fake_response = OpenStruct.new(accounts: [plaid_account], holdings: [holding], securities: [security], request_id: "req_low")

    with_stubbed_plaid_client(investments_holdings_get: fake_response) do
      SyncHoldingsJob.perform_now(item.id)
    end

    pos = item.holdings.find_by(security_id: "sec_low")
    refute pos.high_cost_flag
  end

  # PRD 8: Test nil extended fields handling
  test "handles nil extended fields gracefully" do
    user = User.create!(email: "nil@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_nil", institution_name: "Schwab", access_token: "tok_nil", status: "good")

    balances = OpenStruct.new(current: 500.0, iso_currency_code: "USD")
    plaid_account = OpenStruct.new(account_id: "acc_nil", name: "Acct", mask: "9999", type: "investment", subtype: "brokerage", balances: balances)

    # All extended fields nil
    holding = OpenStruct.new(
      account_id: "acc_nil",
      security_id: "sec_nil",
      quantity: 5.0,
      cost_basis: nil,
      institution_value: 500.0,
      market_value: 500.0,
      vested_value: nil,
      institution_price: nil,
      institution_price_as_of: nil
    )
    security = OpenStruct.new(security_id: "sec_nil", ticker_symbol: "FUND", name: "Mutual Fund")

    fake_response = OpenStruct.new(accounts: [plaid_account], holdings: [holding], securities: [security], request_id: "req_nil")

    with_stubbed_plaid_client(investments_holdings_get: fake_response) do
      SyncHoldingsJob.perform_now(item.id)
    end

    pos = item.holdings.find_by(security_id: "sec_nil")
    refute_nil pos
    assert_nil pos.vested_value
    assert_nil pos.institution_price
    assert_nil pos.institution_price_as_of
    refute pos.high_cost_flag  # Should be false when cost_basis is nil
  end
end
