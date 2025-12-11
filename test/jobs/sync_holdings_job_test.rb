require "test_helper"
require "ostruct"

class SyncHoldingsJobTest < ActiveJob::TestCase
  test "sync creates accounts and positions from Plaid response" do
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
    assert_equal 1, item.positions.count

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

    pos = account.positions.find_by(security_id: "sec_1")
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
end
