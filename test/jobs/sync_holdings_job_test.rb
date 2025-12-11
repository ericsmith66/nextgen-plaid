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
end
