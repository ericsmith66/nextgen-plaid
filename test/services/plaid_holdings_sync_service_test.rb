# test/services/plaid_holdings_sync_service_test.rb
require "test_helper"
require "ostruct"

class PlaidHoldingsSyncServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "holdings_service@example.com", password: "password123")
    @plaid_item = PlaidItem.create!(
      user: @user,
      item_id: "item_holdings_test",
      institution_name: "Test Bank",
      access_token: "tok_holdings",
      status: "good"
    )
    @service = PlaidHoldingsSyncService.new(@plaid_item)
  end

  test "sync fetches and updates holdings" do
    # Mock response
    security = OpenStruct.new(
      security_id: "sec_1",
      ticker_symbol: "AAPL",
      name: "Apple Inc.",
      type: "equity",
      sector: "Technology"
    )
    
    holding = OpenStruct.new(
      account_id: "acc_1",
      security_id: "sec_1",
      quantity: 10,
      institution_value: 1500.0,
      cost_basis: 1000.0
    )
    
    account = OpenStruct.new(
      account_id: "acc_1",
      name: "Brokerage",
      mask: "1234",
      type: "investment",
      subtype: "brokerage",
      balances: OpenStruct.new(current: 5000.0)
    )
    
    response = OpenStruct.new(
      accounts: [account],
      holdings: [holding],
      securities: [security],
      request_id: "req_holdings_123"
    )
    
    Plaid::InvestmentsHoldingsGetRequest.stub :new, ->(*) { Object.new } do
      Rails.application.config.x.plaid_client.stub :investments_holdings_get, response do
        assert_difference 'Holding.count', 1 do
          @service.sync
        end
        
        acc = @plaid_item.accounts.find_by(account_id: "acc_1")
        assert_not_nil acc
        assert_equal "Brokerage", acc.name
        
        h = acc.holdings.first
        assert_equal "AAPL", h.symbol
        assert_equal 1500.0, h.market_value
        assert_equal "Technology", h.sector
        # (1500-1000)/1000 = 0.5. Our logic is gain_ratio > 0.5 for true.
        assert_equal false, h.high_cost_flag
      end
    end
  end
end
